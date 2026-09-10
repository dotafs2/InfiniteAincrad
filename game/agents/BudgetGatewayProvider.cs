using System.Net.Http.Headers;
using System.Runtime.CompilerServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using OpenGameAgent.Kernel;

// Adapts the existing non-streaming budget gateway. The gateway alone owns fees.
// This journal counts this run's attempts; it never creates or resets a balance.
public sealed class BudgetGatewayProvider : IModelProvider, IDisposable
{
    private const string Model = "kimi-k2.6";
    private readonly HttpClient _http;
    private readonly Uri _baseUri;
    private readonly string _token, _ledger, _statePath, _scopeHash;
    private readonly DateTimeOffset _deadline;
    private readonly int _limit;
    private readonly decimal _externalLiability;
    public string Provenance { get; }

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
        _statePath = S(c, "run_state_path");
        var endpointPath = S(c, "endpoint_path");
        Require(Path.IsPathFullyQualified(_statePath) && Path.IsPathFullyQualified(endpointPath));
        _deadline = DateTimeOffset.Parse(S(c, "deadline_utc"), System.Globalization.CultureInfo.InvariantCulture);
        Require(_deadline.Offset == TimeSpan.Zero && _deadline > DateTimeOffset.UtcNow);
        _limit = c.GetProperty("max_requests").GetInt32();
        Require(_limit is >= 1 and <= 3);
        _externalLiability = c.GetProperty("external_liability_cny").GetDecimal();
        Require(_externalLiability >= 0);
        Provenance = S(c, "provenance");
        Require(Provenance is "opengameagent_live" or "opengameagent_fixture");
        using var endpointDocument = JsonDocument.Parse(ReadSmallFile(endpointPath));
        var e = endpointDocument.RootElement;
        Require(S(e, "ledger_id") == _ledger && S(e, "model") == Model);
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
        Require(DateTimeOffset.UtcNow < _deadline && request.Model == Model);
        var latest = request.Messages.Last(m => m.Role == AgentRole.User);
        Require(latest.Metadata.TryGetValue("game.input_id", out var operation) && Guid.TryParse(operation, out _));
        Require(latest.Metadata.TryGetValue("game.actor_id", out var actor) && actor.Length is > 0 and <= 128);
        using var input = JsonDocument.Parse(latest.Content.OfType<JsonContent>().First().Json);
        var root = input.RootElement;
        var payload = root.TryGetProperty("payload", out var p) ? p : root.GetProperty("Payload");
        var view = payload.GetProperty("resident_view");
        // Explicit projection prevents incidental host fields from being sent.
        var personal = new Dictionary<string, JsonElement>();
        foreach (var key in new[] { "identity", "observations", "needs", "experiences", "memory", "inventory", "actions", "available_actions" })
            personal[key] = view.GetProperty(key);
        var observation = JsonSerializer.Serialize(personal);
        const string instructions = "You are this resident, using only your personal observations and experiences. " +
            "Choose one action from available_actions: wait, draw_water, drink_water. An available action is optional. " +
            "Return only JSON {action,reason}; give reason in Simplified Chinese, at most 512 characters. " +
            "If no available action meets your need, you may additionally propose need:{capability_id:<short missing ability ID>,reason:<your reason>}. " +
            "Do not request an ability you already observe working; a proposal does not create it. Waiting without a need is valid. " +
            "Do not invent resources or memories, install anything, modify rules, or include any other fields.";
        Require(Encoding.UTF8.GetByteCount(instructions + observation) <= 24576);
        var body = JsonSerializer.Serialize(new { model = Model, messages = new[] {
            new { role = "system", content = instructions }, new { role = "user", content = observation } },
            stream = false, max_tokens = 512, thinking = new { type = "disabled" }, response_format = new { type = "json_object" } });
        Require(Encoding.UTF8.GetByteCount(body) <= 32768);

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
            Require(preflight.RootElement.GetProperty("remaining_allocatable_cny").GetDecimal() >= 1.718m + _externalLiability);
        }
        Require(DateTimeOffset.UtcNow < _deadline);
        state.Count++;
        state.Unknown = true;
        state.Operation = operation!;
        WriteState(stateFile, state); // Durable before sending: crash/timeout cannot mint another attempt.
        using var reply = await Send(HttpMethod.Post, "/v1/chat/completions", body, operation, actor, ct).ConfigureAwait(false);
        var result = reply.RootElement;
        Require(S(result, "model") == Model);
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
            new ModelUsage(prompt, output, cached), provider: "budget-gateway", responseModel: Model);
        state.Unknown = false;
        WriteState(stateFile, state);
        return response;
    }

    private void ValidateBudget(JsonElement budget)
    {
        Require(S(budget, "ledger_id") == _ledger && budget.GetProperty("halted").GetString() == "");
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
