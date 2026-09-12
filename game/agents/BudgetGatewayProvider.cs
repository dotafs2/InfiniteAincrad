using System.Collections.Concurrent;
using System.Net.Http.Headers;
using System.Runtime.CompilerServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using OpenGameAgent.Kernel;

// Adapts the existing non-streaming budget gateway. The gateway alone owns fees.
// This journal counts this run's attempts; it never creates or resets a balance.
public sealed class BudgetGatewayProvider : IModelProvider, IDisposable
{
    // Backward-compatible default. A run may pin another model through an
    // explicit run-scoped `expected_model`; the loopback ledger gateway, not
    // this host, remains the sole fee and credential owner.
    private const string DefaultModel = "kimi-k2.6";
    // This is UTF-8 JSON in an HTTP body, never embedded in HTML. Escaping
    // Chinese as six ASCII characters needlessly exhausts the byte budget.
    private static readonly JsonSerializerOptions WireJson = new()
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
    };
    // Multiple resident adapters in this process share one durable run journal.
    // Wait before opening its exclusive handle instead of quarantining a healthy
    // resident with a sharing violation. External processes still fail closed.
    private static readonly ConcurrentDictionary<string, SemaphoreSlim> JournalGates = new(
        OperatingSystem.IsWindows() ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal);
    private readonly HttpClient _http;
    private readonly Uri _baseUri;
    private readonly string _token, _ledger, _statePath, _scopeHash;
    private readonly string _model;
    private readonly DateTimeOffset _deadline;
    private readonly int _limit;
    private readonly decimal _externalLiability;
    public string Provenance { get; }
    // The pinned model id is published so the host runtime requests exactly it.
    public string ModelId => _model;

    private sealed class RunState
    {
        public string Scope { get; set; } = "";
        public int Count { get; set; }
        public bool Unknown { get; set; }
        public string Operation { get; set; } = "";
    }

    public BudgetGatewayProvider(string configPath)
    {
        Require(Path.IsPathFullyQualified(configPath));
        var raw = ReadSmallFile(configPath);
        using var document = JsonDocument.Parse(raw);
        var c = document.RootElement;
        Require(c.GetProperty("schema_version").GetInt32() == 1);
        _ledger = S(c, "expected_ledger_id");
        if (c.TryGetProperty("expected_model", out var pinned))
        {
            Require(pinned.ValueKind == JsonValueKind.String);
            _model = PinnedModel(pinned.GetString()!);
        }
        else
        {
            _model = DefaultModel;
        }
        _statePath = S(c, "run_state_path");
        var endpointPath = S(c, "endpoint_path");
        Require(Path.IsPathFullyQualified(_statePath) && Path.IsPathFullyQualified(endpointPath));
        _statePath = Path.GetFullPath(_statePath);
        _deadline = DateTimeOffset.Parse(S(c, "deadline_utc"), System.Globalization.CultureInfo.InvariantCulture);
        Require(_deadline.Offset == TimeSpan.Zero && _deadline > DateTimeOffset.UtcNow);
        _limit = c.GetProperty("max_requests").GetInt32();
        Require(_limit is >= 1 and <= 32);
        _externalLiability = c.GetProperty("external_liability_cny").GetDecimal();
        Require(_externalLiability >= 0);
        Provenance = S(c, "provenance");
        Require(Provenance is "opengameagent_live" or "opengameagent_fixture");
        using var endpointDocument = JsonDocument.Parse(ReadSmallFile(endpointPath));
        var e = endpointDocument.RootElement;
        Require(S(e, "ledger_id") == _ledger && S(e, "model") == _model);
        _baseUri = new Uri(S(e, "base_url"), UriKind.Absolute);
        Require(_baseUri.Scheme == "http" && _baseUri.Host == "127.0.0.1" && _baseUri.AbsolutePath == "/v1"
            && _baseUri.UserInfo.Length == 0 && _baseUri.Query.Length == 0 && _baseUri.Fragment.Length == 0);
        _token = S(e, "api_key");
        Require(_token.Length is > 0 and < 512 && !_token.Any(char.IsWhiteSpace));
        _scopeHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(raw)));
        _http = new HttpClient(new HttpClientHandler { UseProxy = false, AllowAutoRedirect = false })
            { Timeout = TimeSpan.FromSeconds(35) };
    }

    public async IAsyncEnumerable<ModelStreamEvent> StreamAsync(ModelRequest request,
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        ModelResponse response;
        try
        {
            using var bounded = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            bounded.CancelAfter(TimeSpan.FromSeconds(35));
            response = await Complete(request, bounded.Token).ConfigureAwait(false);
        }
        catch
        {
            // Keep credentials, URLs, response bodies and filesystem paths out of logs.
            throw new InvalidOperationException("budget_gateway_rejected_or_uncertain");
        }
        yield return ModelStreamEvent.Terminal(response);
    }

    private async Task<ModelResponse> Complete(ModelRequest request, CancellationToken ct)
    {
        Require(DateTimeOffset.UtcNow < _deadline && request.Model == _model);
        var latest = request.Messages.Last(m => m.Role == AgentRole.User);
        Require(latest.Metadata.TryGetValue("game.input_id", out var operation) && Guid.TryParse(operation, out _));
        Require(latest.Metadata.TryGetValue("game.actor_id", out var actor) && actor.Length is > 0 and <= 128);
        using var input = JsonDocument.Parse(latest.Content.OfType<JsonContent>().First().Json);
        var root = input.RootElement;
        var payload = root.TryGetProperty("payload", out var p) ? p : root.GetProperty("Payload");
        var view = payload.GetProperty("resident_view");
        // Explicit projection prevents incidental host fields from being sent.
        var personal = new Dictionary<string, JsonElement>();
        foreach (var key in new[] { "identity", "observations", "needs", "experiences", "memory", "inventory", "actions", "available_actions",
            "nearby_residents", "items", "skills", "contracts", "life_account", "wallet", "nearby_skilled_roles", "action_details", "known_rules", "unavailable_actions" })
            if (view.TryGetProperty(key, out var value)) personal[key] = value;
        Require(personal.ContainsKey("identity") && personal.ContainsKey("available_actions"));
        Require(S(personal["identity"], "id") == actor);
        // These are the town's recipient-filtered historical projections, never
        // the world event log, another resident's view, or the GM installation state.
        // Keep the latest bounded records independently of the 16 recent events.
        ProjectKnowledge(view, personal, "known_skill_notices", 16,
            "actor_id", "skill_id", "source_event_id", "seq", "source", "provenance", "text");
        ProjectKnowledge(view, personal, "known_skill_referrals", 16,
            "referrer_id", "referred_resident_id", "skill_id", "referral_event_id", "seq", "source_event_id", "source_seq", "provenance", "text");
        ProjectKnowledge(view, personal, "material_sources", 8,
            "id", "label", "material", "access", "position", "last_observed_stock", "observed_elapsed", "observation_event_seq",
            "knowledge_source", "work_seconds_per_unit", "stock_may_have_changed");
        var observation = JsonSerializer.Serialize(personal, WireJson);
        const string instructions = "You are this resident, using only your personal observations and experiences. " +
            "Choose exactly one action ID from available_actions. action_details explains the offered choices. An available action is optional. " +
            "Return only JSON {action,reason}; give reason in Simplified Chinese, at most 512 characters. " +
            "reason is private and never spoken. For an action with speech_allowed=true, you may add speech (public words in Simplified Chinese, at most512 characters) to explain or ask in your own words. Public speech is an attributed statement, not a change to contract terms or resources. " +
            "If no available action meets your need, you may additionally propose need:{capability_id:<short missing ability ID>,reason:<your reason>}. " +
            "Do not request an ability you already observe working; a proposal does not create it. Waiting without a need is valid. " +
            "World inventory, contract fields and known_rules describe authoritative current facts. Previous reasons and spoken statements can be mistaken beliefs; revise those beliefs when they conflict with current facts, without rewriting history. " +
            "known_skill_notices, known_skill_referrals and material_sources are bounded personal historical knowledge, not proof of current skills, availability or stock. Their absence does not prove nobody has a skill or that no material exists. " +
            "Other residents may refuse; only a recorded contract or action receipt establishes an outcome. " +
            "Do not invent resources or memories, install anything, modify rules, or include any other fields.";
        Require(Encoding.UTF8.GetByteCount(instructions + observation) <= 24576);
        var body = JsonSerializer.Serialize(new { model = _model, messages = new[] {
            new { role = "system", content = instructions }, new { role = "user", content = observation } },
            stream = false, max_tokens = 512, thinking = new { type = "disabled" }, response_format = new { type = "json_object" } }, WireJson);
        Require(Encoding.UTF8.GetByteCount(body) <= 32768);

        var gate = JournalGates.GetOrAdd(_statePath, _ => new SemaphoreSlim(1, 1));
        await gate.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            // A cancelled/deadline-expired waiter has not attempted an upstream call.
            ct.ThrowIfCancellationRequested();
            Require(DateTimeOffset.UtcNow < _deadline);
            return await CompleteRecorded(body, operation!, actor!, ct).ConfigureAwait(false);
        }
        finally
        {
            gate.Release();
        }
    }

    private async Task<ModelResponse> CompleteRecorded(string body, string operation, string actor, CancellationToken ct)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_statePath)!);
        var existed = File.Exists(_statePath);
        using var stateFile = new FileStream(_statePath, existed ? FileMode.Open : FileMode.CreateNew,
            FileAccess.ReadWrite, FileShare.None);
        Require(stateFile.Length <= 32768);
        var state = existed ? JsonSerializer.Deserialize<RunState>(stateFile) ?? throw new InvalidOperationException()
            : new RunState { Scope = _scopeHash };
        Require(state.Scope == _scopeHash && state.Count >= 0 && state.Count < _limit && !state.Unknown);
        WriteState(stateFile, state);
        using (var preflight = await Send(HttpMethod.Get, "/budget", null, null, null, ct).ConfigureAwait(false))
        {
            ValidateBudget(preflight.RootElement);
            // The ledger atomically reserves its own policy-specific worst case.
            // Do not impose the obsolete 262k-context price on a smaller run policy.
            Require(preflight.RootElement.GetProperty("remaining_allocatable_cny").GetDecimal() > _externalLiability);
        }
        Require(DateTimeOffset.UtcNow < _deadline);
        state.Count++;
        state.Unknown = true;
        state.Operation = operation!;
        WriteState(stateFile, state); // Durable before sending: crash/timeout cannot mint another attempt.
        using var reply = await Send(HttpMethod.Post, "/v1/chat/completions", body, operation, actor, ct).ConfigureAwait(false);
        var result = reply.RootElement;
        Require(S(result, "model") == _model);
        ValidateBudget(result.GetProperty("_hearth_budget"));
        var usage = result.GetProperty("usage");
        var prompt = usage.GetProperty("prompt_tokens").GetInt64();
        var output = usage.GetProperty("completion_tokens").GetInt64();
        long cached = usage.TryGetProperty("prompt_tokens_details", out var details) && details.TryGetProperty("cached_tokens", out var hit)
            ? hit.GetInt64() : 0;
        Require(prompt is >= 0 and <= 262144 && output is >= 0 and <= 512 && cached >= 0 && cached <= prompt
            && usage.GetProperty("total_tokens").GetInt64() == prompt + output);
        var text = S(result.GetProperty("choices")[0].GetProperty("message"), "content");
        var response = new ModelResponse(new AgentContent[] { new TextContent(text) }, ModelStopReason.Stop,
            new ModelUsage(prompt, output, cached), provider: "budget-gateway", responseModel: _model);
        state.Unknown = false;
        WriteState(stateFile, state);
        return response;
    }

    private static void ProjectKnowledge(JsonElement view, Dictionary<string, JsonElement> personal,
        string key, int limit, params string[] fields)
    {
        if (!view.TryGetProperty(key, out var records)) return; // Legacy well views have none.
        Require(records.ValueKind == JsonValueKind.Array);
        var projected = new List<Dictionary<string, JsonElement>>();
        // Preserve whole source-attributed records. Incidental nested private fields
        // cannot ride along when a future host adds data to one of these records.
        foreach (var record in records.EnumerateArray().Reverse().Take(limit))
        {
            Require(record.ValueKind == JsonValueKind.Object);
            var entry = new Dictionary<string, JsonElement>();
            foreach (var field in fields)
            {
                var value = record.GetProperty(field);
                if (field == "position")
                {
                    Require(value.ValueKind == JsonValueKind.Array && value.GetArrayLength() == 3);
                    foreach (var coordinate in value.EnumerateArray())
                        Require(coordinate.ValueKind == JsonValueKind.Number && double.IsFinite(coordinate.GetDouble()));
                }
                else
                {
                    Require(value.ValueKind is JsonValueKind.String or JsonValueKind.Number or JsonValueKind.True or JsonValueKind.False);
                    if (value.ValueKind == JsonValueKind.String) Require(value.GetString()!.Length <= 512);
                }
                entry[field] = value;
            }
            projected.Add(entry);
        }
        projected.Reverse();
        personal[key] = JsonSerializer.SerializeToElement(projected, WireJson);
        // The existing 24 KiB prompt and 32 KiB wire guards still apply to all
        // knowledge together; a large input must never enlarge the paid context.
    }

    private void ValidateBudget(JsonElement budget)
    {
        Require(S(budget, "ledger_id") == _ledger && budget.GetProperty("halted").GetString() == "");
    }

    // A model id is a short ASCII token, never host config, a URL or a prompt.
    private static string PinnedModel(string value)
    {
        Require(value.Length is >= 1 and <= 64);
        foreach (var ch in value) Require(char.IsAsciiLetterOrDigit(ch) || ch is '.' or '-' or '_' or ':' or '/');
        return value;
    }

    private async Task<JsonDocument> Send(HttpMethod method, string path, string? body, string? operation,
        string? actor, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(method, new Uri(_baseUri, path));
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _token);
        if (operation != null) request.Headers.Add("X-Hearth-Operation", operation);
        if (actor != null) request.Headers.Add("X-Hearth-Resident", actor);
        if (body != null) request.Content = new StringContent(body, Encoding.UTF8, "application/json");
        using var response = await _http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct).ConfigureAwait(false);
        Require(response.IsSuccessStatusCode);
        await using var source = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
        using var bytes = new MemoryStream();
        var buffer = new byte[4096];
        int count;
        while ((count = await source.ReadAsync(buffer, ct).ConfigureAwait(false)) > 0)
        {
            Require(bytes.Length + count <= 131072);
            bytes.Write(buffer, 0, count);
        }
        return JsonDocument.Parse(bytes.ToArray());
    }

    private static void WriteState(FileStream file, RunState state)
    {
        file.Position = 0;
        file.SetLength(0);
        JsonSerializer.Serialize(file, state);
        file.Flush(true); // A partial write remains unreadable and therefore fails closed.
    }
    private static string ReadSmallFile(string path)
    {
        Require(new FileInfo(path).Length is > 0 and <= 32768);
        return File.ReadAllText(path);
    }
    private static string S(JsonElement e, string key) => e.GetProperty(key).GetString() ?? throw new InvalidOperationException();
    private static void Require(bool valid) { if (!valid) throw new InvalidOperationException("gateway_validation_failed"); }
    public void Dispose() => _http.Dispose();
}
