"""Contain one tool-owned Windows process tree; no name-based process cleanup."""
import ctypes
from ctypes import wintypes as W
import os
import subprocess
import time


class _Limits(ctypes.Structure):
    _fields_ = [('process_time', ctypes.c_longlong), ('job_time', ctypes.c_longlong),
                ('flags', W.DWORD), ('min_ws', ctypes.c_size_t), ('max_ws', ctypes.c_size_t),
                ('active_limit', W.DWORD), ('affinity', ctypes.c_size_t),
                ('priority', W.DWORD), ('scheduling', W.DWORD)]


class _ExtendedLimits(ctypes.Structure):
    _fields_ = [('basic', _Limits), ('io', ctypes.c_ulonglong * 6),
                ('process_memory', ctypes.c_size_t), ('job_memory', ctypes.c_size_t),
                ('peak_process_memory', ctypes.c_size_t), ('peak_job_memory', ctypes.c_size_t)]


class _Accounting(ctypes.Structure):
    _fields_ = [('times', ctypes.c_longlong * 4), ('page_faults', W.DWORD),
                ('total', W.DWORD), ('active', W.DWORD), ('terminated', W.DWORD)]


class _ThreadEntry(ctypes.Structure):
    _fields_ = [('size', W.DWORD), ('usage', W.DWORD), ('tid', W.DWORD),
                ('owner', W.DWORD), ('base_priority', W.LONG), ('delta_priority', W.LONG), ('flags', W.DWORD)]


if os.name == 'nt':
    _k = ctypes.WinDLL('kernel32', use_last_error=True)
    for name, result, arguments in [
        ('CreateJobObjectW', W.HANDLE, [ctypes.c_void_p, W.LPCWSTR]),
        ('SetInformationJobObject', W.BOOL, [W.HANDLE, ctypes.c_int, ctypes.c_void_p, W.DWORD]),
        ('QueryInformationJobObject', W.BOOL, [W.HANDLE, ctypes.c_int, ctypes.c_void_p, W.DWORD, ctypes.c_void_p]),
        ('AssignProcessToJobObject', W.BOOL, [W.HANDLE, W.HANDLE]),
        ('IsProcessInJob', W.BOOL, [W.HANDLE, W.HANDLE, ctypes.POINTER(W.BOOL)]),
        ('TerminateJobObject', W.BOOL, [W.HANDLE, W.UINT]),
        ('CloseHandle', W.BOOL, [W.HANDLE]),
        ('OpenProcess', W.HANDLE, [W.DWORD, W.BOOL, W.DWORD]),
        ('GetProcessTimes', W.BOOL, [W.HANDLE, ctypes.POINTER(W.FILETIME), ctypes.POINTER(W.FILETIME), ctypes.POINTER(W.FILETIME), ctypes.POINTER(W.FILETIME)]),
        ('GetExitCodeProcess', W.BOOL, [W.HANDLE, ctypes.POINTER(W.DWORD)]),
        ('WaitForSingleObject', W.DWORD, [W.HANDLE, W.DWORD]),
        ('CreateToolhelp32Snapshot', W.HANDLE, [W.DWORD, W.DWORD]),
        ('Thread32First', W.BOOL, [W.HANDLE, ctypes.POINTER(_ThreadEntry)]),
        ('Thread32Next', W.BOOL, [W.HANDLE, ctypes.POINTER(_ThreadEntry)]),
        ('OpenThread', W.HANDLE, [W.DWORD, W.BOOL, W.DWORD]),
        ('ResumeThread', W.DWORD, [W.HANDLE]),
    ]:
        function = getattr(_k, name)
        function.restype, function.argtypes = result, arguments


def _check(ok):
    if not ok:
        raise ctypes.WinError(ctypes.get_last_error())


class WindowsProcessTree:
    """Start suspended, assign a kill-on-close job, then resume the owned wrapper.

    The kernel contains descendants even if the Python runner is abruptly killed.
    Polling records observed member identities; short-lived unobserved members are
    counted by the job and explicitly marked incomplete, never invented.
    """
    def __init__(self, command, **kwargs):
        if os.name != 'nt':
            raise OSError('Windows job containment is only available on Windows')
        self.command, self.process, self._members = command, None, {}
        self._job = _k.CreateJobObjectW(None, None)
        _check(self._job)
        try:
            limits = _ExtendedLimits()
            limits.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE; no breakaway.
            _check(_k.SetInformationJobObject(self._job, 9, ctypes.byref(limits), ctypes.sizeof(limits)))
            self.process = subprocess.Popen(command, creationflags=subprocess.CREATE_NO_WINDOW | 0x4, **kwargs)
            _check(_k.AssignProcessToJobObject(self._job, int(self.process._handle)))
            self.snapshot()
            self._resume_primary_thread()
        except BaseException:
            # No execution is allowed before job assignment. Never fall back to
            # an uncontained process if assignment or resume fails.
            try:
                if self.process is not None and self.process.poll() is None:
                    self.process.kill()
                    self.process.wait(timeout=5)
            finally:
                try:
                    self.close()
                except BaseException:
                    pass  # Preserve original startup failure; close has a kill-on-close finally.
            raise

    def _resume_primary_thread(self):
        snapshot = _k.CreateToolhelp32Snapshot(0x4, 0)  # TH32CS_SNAPTHREAD.
        _check(snapshot and snapshot != ctypes.c_void_p(-1).value)
        try:
            entry = _ThreadEntry()
            entry.size = ctypes.sizeof(entry)
            found = _k.Thread32First(snapshot, ctypes.byref(entry))
            while found:
                if entry.owner == self.process.pid:
                    thread = _k.OpenThread(0x2, False, entry.tid)
                    _check(thread)
                    try:
                        _check(_k.ResumeThread(thread) != 0xffffffff)
                        return
                    finally:
                        _k.CloseHandle(thread)
                found = _k.Thread32Next(snapshot, ctypes.byref(entry))
            raise RuntimeError('Owned suspended process primary thread was not found')
        finally:
            _k.CloseHandle(snapshot)

    def snapshot(self):
        accounting = _Accounting()
        _check(_k.QueryInformationJobObject(self._job, 1, ctypes.byref(accounting), ctypes.sizeof(accounting), None))
        capacity = 32
        while True:
            buffer = ctypes.create_string_buffer(8 + ctypes.sizeof(ctypes.c_size_t) * capacity)
            if _k.QueryInformationJobObject(self._job, 3, buffer, len(buffer), None):
                break
            if ctypes.get_last_error() != 234 or capacity >= 4096:
                _check(False)
            capacity *= 2
        count = W.DWORD.from_buffer(buffer, 4).value
        pids = (ctypes.c_size_t * count).from_buffer(buffer, 8)
        for pid in pids:
            if pid in self._members:
                continue
            handle = _k.OpenProcess(0x100000 | 0x1000, False, pid)
            if not handle:  # A very short-lived member may already have exited.
                continue
            belongs = W.BOOL()
            if not _k.IsProcessInJob(handle, self._job, ctypes.byref(belongs)) or not belongs.value:
                _k.CloseHandle(handle)  # PID reuse is not ownership.
                continue
            times = [W.FILETIME() for _ in range(4)]
            if not _k.GetProcessTimes(handle, *(ctypes.byref(value) for value in times)):
                _k.CloseHandle(handle)
                continue
            created = (times[0].dwHighDateTime << 32) | times[0].dwLowDateTime
            self._members[int(pid)] = (handle, created)
        members = []
        for pid, (handle, created) in self._members.items():
            running = _k.WaitForSingleObject(handle, 0) == 258
            code = W.DWORD()
            known = not running and _k.GetExitCodeProcess(handle, ctypes.byref(code))
            members.append({'pid': pid, 'creation_time_windows_100ns': created,
                            'running': running, 'exit_code': code.value if known else None})
        return {'containment': 'windows_kill_on_close_job', 'wrapper_pid': self.process.pid if self.process else None,
                'observed_members': members, 'total_assigned_processes': accounting.total,
                'active_processes': accounting.active,
                'member_identity_list_complete': len(members) == accounting.total,
                'observed_nonzero_exits': [member for member in members if member['exit_code'] not in (None, 0)],
                'all_member_exit_codes_known': len(members) == accounting.total and all(member['exit_code'] is not None for member in members),
                'all_members_exited': accounting.active == 0 and not any(member['running'] for member in members)}

    def wait(self, timeout, on_poll=None):
        deadline = time.monotonic() + timeout
        while True:
            self.process.poll()
            state = self.snapshot()
            if on_poll is not None:
                on_poll(state)
            if state['all_members_exited']:
                return self.process.wait(timeout=5)
            if time.monotonic() >= deadline:
                raise subprocess.TimeoutExpired(self.command, timeout)
            time.sleep(0.05)

    def terminate(self, exit_code=130):
        _check(_k.TerminateJobObject(self._job, exit_code))
        deadline = time.monotonic() + 5
        while not self.snapshot()['all_members_exited']:
            if time.monotonic() >= deadline:
                raise RuntimeError('Owned Windows job did not drain after termination')
            time.sleep(0.02)
        if self.process is not None:
            self.process.wait(timeout=5)

    def close(self):
        if not self._job:
            return
        try:
            if not self.snapshot()['all_members_exited']:
                self.terminate()
        finally:
            _k.CloseHandle(self._job)  # Kernel kill-on-close also covers cleanup exceptions.
            self._job = None
            try:
                if self.process is not None:
                    self.process.wait(timeout=5)
            finally:
                for handle, _created in self._members.values():
                    _k.CloseHandle(handle)

    def __enter__(self):
        return self

    def __exit__(self, kind, value, traceback):
        try:
            self.close()
        except BaseException:
            if kind is None:
                raise
            # Preserve the original callback/interrupt error; close() still closes
            # the kernel job handle in its finally block and therefore kills members.
        return False
