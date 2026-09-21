using System.Collections.Generic;
using System.Net.Http.Headers;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using OpenGameAgent.Kernel;

// Keeps inexpensive, low-risk resident turns on the loopback LocalJev service.
// The existing BudgetGatewayProvider remains the only cloud/fee owner and is
// used for every policy-forced route or uncertain local result.
public sealed class LocalFirstProvider : IModelProvider, IDisposable
{
    private const string EnabledVariable = "AINCRAD_LOCALJEV_ENABLED";
    private const string BaseUrlVariable = "AINCRAD_LOCALJEV_URL";
    private const string ApiKeyVariable = "AINCRAD_LOCALJEV_API_KEY";
    private const string ModelVariable = "AINCRAD_LOCALJEV_MODEL";
    private const string ThresholdVariable = "AINCRAD_LOCALJEV_CONFIDENCE";
    private const string DefaultBaseUrl = "http://127.0.0.1:8080/";
    private const string DefaultModel = "qwen3:8b";
    private const double DefaultThreshold = 0.75;
    private const int MaxBodyBytes = 131072;
    private const string CloudSocial = "cloud_social";
    private const string LocalRoutine = "local_routine";

    private static readonly JsonSerializerOptions WireJson = new()
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    private readonly BudgetGatewayProvider _cloud;
    private readonly HttpClient _http;
    private readonly Uri _baseUri;
    private readonly string _apiKey;
    private readonly string _localModel;
    private readonly double _threshold;
    private readonly bool _enabled;

    public LocalFirstProvider(BudgetGatewayProvider cloud)
    {
        _cloud = cloud ?? throw new ArgumentNullException(nameof(cloud));
        _enabled = IsTrue(Environment.GetEnvironmentVariable(EnabledVariable));
        if (!_enabled)
        {
            _localModel = DefaultModel;
            _threshold = DefaultThreshold;
            _baseUri = new Uri(DefaultBaseUrl, UriKind.Absolute);
            _http = new HttpClient();
            _apiKey = string.Empty;
            return;
        }

        var rawBase = Environment.GetEnvironmentVariable(BaseUrlVariable);
        _baseUri = ParseLoopbackBase(rawBase is null ? DefaultBaseUrl : rawBase);
        _apiKey = Environment.GetEnvironmentVariable(ApiKeyVariable) ?? string.Empty;
        Require(_apiKey.Length < 512 && !_apiKey.Any(char.IsWhiteSpace));
        _localModel = PinnedIdentifier(Environment.GetEnvironmentVariable(ModelVariable) ?? DefaultModel);
        _threshold = ParseThreshold(Environment.GetEnvironmentVariable(ThresholdVariable));
        _http = new HttpClient(new HttpClientHandler { UseProxy = false, AllowAutoRedirect = false })
        {
            Timeout = TimeSpan.FromSeconds(12),
        };
    }

    public string ModelId => _cloud.ModelId;

    public async IAsyncEnumerable<ModelStreamEvent> StreamAsync(ModelRequest request,
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        if (!_enabled)
        {
            await foreach (var item in _cloud.StreamAsync(request, cancellationToken).ConfigureAwait(false))
                yield return item;
            yield break;
        }

        ModelResponse response;
        try
        {
            var input = ReadInput(request);
            var route = await Route(input.View, input.Actor, cancellationToken).ConfigureAwait(false);
            if (route.SelectedRoute != LocalRoutine)
            {
                response = await CompleteCloud(request, route, "policy_or_router_route", cancellationToken).ConfigureAwait(false);
            }
            else
            {
                var local = await DecideLocally(input.View, input.Actor, route, cancellationToken).ConfigureAwait(false);
                response = local ?? await CompleteCloud(request, route,
                    "local_decision_confidence_below_threshold", cancellationToken).ConfigureAwait(false);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (OperationCanceledException)
        {
            // HttpClient uses TaskCanceledException for its own timeout. The
            // caller did not cancel this turn, so treat a local timeout like
            // any other optional-service failure and try the cloud provider.
            response = await CompleteCloud(request,
                new RouteResult(LocalRoutine, 0, true, "local_service_timeout", "localjev", _localModel),
                "local_service_timeout", cancellationToken).ConfigureAwait(false);
        }
        catch
        {
            // LocalJev is an optional optimization. A stopped or malformed local
            // service must never turn a safe resident turn into a false success.
            response = await CompleteCloud(request,
                new RouteResult(LocalRoutine, 0, true, "local_service_unavailable", "localjev", _localModel),
                "local_service_unavailable", cancellationToken).ConfigureAwait(false);
        }
        yield return ModelStreamEvent.Terminal(response);
    }

    private async Task<ModelResponse?> DecideLocally(JsonElement view, string actor,
        RouteResult route, CancellationToken cancellationToken)
    {
        var actions = ActionLabels(view);
        if (actions.Count < 2)
            return null;

        var criteria = new Dictionary<string, string>();
        foreach (var pair in actions)
            criteria[pair.Key] = pair.Value;

        var body = JsonSerializer.Serialize(new
        {
            model = "localjev-latest",
            state = new { resident_id = actor, resident_view = view },
            questions = new
            {
                action = new
                {
                    type = "choice",
                    instructions = "Choose exactly one available routine action for this resident turn. Do not choose a social, contract, scarce-resource, or story action.",
                    criteria,
                },
            },
        }, WireJson);

        using var document = await Send(HttpMethod.Post, "/v1/systemone", body, cancellationToken).ConfigureAwait(false);
        var root = document.RootElement;
        var answers = root.GetProperty("answers");
        var answer = answers.GetProperty("action");
        Require(answer.GetProperty("type").GetString() == "choice");
        var choice = answer.GetProperty("choice").GetString() ?? string.Empty;
        var confidence = answer.GetProperty("confidence").GetDouble();
        Require(double.IsFinite(confidence) && confidence >= 0 && confidence <= 1);
        if (!criteria.ContainsKey(choice) || confidence < _threshold)
            return null;

        var label = criteria[choice];
        var reason = label.Length == 0
            ? "I choose this routine action because it best fits my current needs."
            : $"I choose {label} because it best fits my current needs.";
        var decision = JsonSerializer.Serialize(new { action = choice, reason }, WireJson);
        var usage = Usage(root);
        var metadata = new RouteMetadata(route, confidence, false, null, _localModel);
        return new ModelResponse(new AgentContent[] { new TextContent(decision) }, ModelStopReason.Stop,
            usage, provider: "localjev", api: "systemone", responseModel: _localModel,
            responseId: metadata.Serialize());
    }

    private async Task<ModelResponse> CompleteCloud(ModelRequest request, RouteResult route, string fallbackReason,
        CancellationToken cancellationToken)
    {
        await foreach (var item in _cloud.StreamAsync(request, cancellationToken).ConfigureAwait(false))
        {
            if (item.Response is null)
                continue;
            var metadata = new RouteMetadata(route, null, true, fallbackReason, _cloud.ModelId);
            var response = item.Response;
            return new ModelResponse(response.Content, response.StopReason, response.Usage,
                response.ErrorMessage, response.Provider, response.Api, response.ResponseModel,
                metadata.Serialize(), response.RawStopReason, response.EndTurn,
                response.Diagnostics, response.Deferred);
        }
        throw new InvalidOperationException("cloud_provider_returned_no_response");
    }

    private async Task<RouteResult> Route(JsonElement view, string actor, CancellationToken cancellationToken)
    {
        var labels = ActionLabels(view);
        var text = string.Join(" | ", labels.Values).ToLowerInvariant();
        var requiresDialogue = HasAny(text, "talk", "ask ", "tell ", "reply", "invite", "accept", "decline", "teach", "speak", "say ");
        var multiParty = HasAny(text, "another resident", "with ", "share", "trade", "contract", "help", "invite", "reply", "ask ");
        var scarce = HasAny(text, "repair", "iron", "material", "flour", "bread", "bake", "give", "trade", "recover", "harvest");
        var irreversible = HasAny(text, "repair", "bake", "trade", "give", "recover", "harvest");
        var storyCritical = HasAny(text, "story", "canon", "floor", "boss", "quest");

        var candidates = new[]
        {
            new { model = _localModel, route_class = LocalRoutine },
            new { model = _cloud.ModelId, route_class = CloudSocial },
            new { model = _cloud.ModelId, route_class = "cloud_story_critical" },
            new { model = _cloud.ModelId, route_class = "gm_review" },
        };
        var body = JsonSerializer.Serialize(new
        {
            state = new { resident_id = actor, available_actions = labels.Keys.ToArray(), action_labels = labels.Values.ToArray() },
            task_type = "resident_turn",
            requires_dialogue = requiresDialogue,
            irreversible,
            scarce_resource = scarce,
            story_critical = storyCritical,
            multi_party = multiParty,
            candidates,
        }, WireJson);

        using var document = await Send(HttpMethod.Post, "/v1/route", body, cancellationToken).ConfigureAwait(false);
        var root = document.RootElement;
        var selectedRoute = root.GetProperty("selected_route").GetString() ?? string.Empty;
        Require(selectedRoute is LocalRoutine or CloudSocial or "cloud_story_critical" or "gm_review");
        var confidence = root.GetProperty("route_confidence").GetDouble();
        Require(double.IsFinite(confidence) && confidence >= 0 && confidence <= 1);
        var selectedModel = root.GetProperty("selected_model").GetString() ?? string.Empty;
        var routerModel = root.GetProperty("router_model").GetString() ?? string.Empty;
        Require(selectedModel.Length > 0 && routerModel.Length > 0);
        var fallback = root.GetProperty("fallback").GetBoolean();
        string? reason = null;
        if (root.TryGetProperty("fallback_reason", out var fallbackReason) && fallbackReason.ValueKind != JsonValueKind.Null)
            reason = fallbackReason.GetString();
        return new RouteResult(selectedRoute, confidence, fallback, reason, routerModel, selectedModel);
    }

    private async Task<JsonDocument> Send(HttpMethod method, string path, string body, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(method, new Uri(_baseUri, path));
        if (_apiKey.Length > 0)
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
        request.Content = new StringContent(body, Encoding.UTF8, "application/json");
        using var response = await _http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken).ConfigureAwait(false);
        Require(response.IsSuccessStatusCode);
        await using var source = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
        using var bytes = new MemoryStream();
        var buffer = new byte[4096];
        int count;
        while ((count = await source.ReadAsync(buffer, cancellationToken).ConfigureAwait(false)) > 0)
        {
            Require(bytes.Length + count <= MaxBodyBytes);
            bytes.Write(buffer, 0, count);
        }
        return JsonDocument.Parse(bytes.ToArray());
    }

    private static (JsonElement View, string Actor) ReadInput(ModelRequest request)
    {
        Require(request.Model.Length > 0);
        var latest = request.Messages.Last(m => m.Role == AgentRole.User);
        Require(latest.Metadata.TryGetValue("game.actor_id", out var actor) && actor.Length > 0 && actor.Length <= 128);
        using var input = JsonDocument.Parse(latest.Content.OfType<JsonContent>().First().Json);
        var root = input.RootElement;
        var payload = root.TryGetProperty("payload", out var camel) ? camel : root.GetProperty("Payload");
        var view = payload.GetProperty("resident_view");
        Require(view.ValueKind == JsonValueKind.Object && view.TryGetProperty("available_actions", out _));
        return (view.Clone(), actor!);
    }

    private static Dictionary<string, string> ActionLabels(JsonElement view)
    {
        var labels = new Dictionary<string, string>();
        if (!view.TryGetProperty("available_actions", out var available) || available.ValueKind != JsonValueKind.Array)
            return labels;
        var detailLabels = new Dictionary<string, string>();
        if (view.TryGetProperty("action_details", out var details) && details.ValueKind == JsonValueKind.Array)
            foreach (var detail in details.EnumerateArray())
                if (detail.TryGetProperty("id", out var id) && detail.TryGetProperty("label", out var label))
                    detailLabels[id.GetString() ?? ""] = label.GetString() ?? "";
        if (view.TryGetProperty("action_groups", out var groups) && groups.ValueKind == JsonValueKind.Object)
            foreach (var group in groups.EnumerateObject())
            {
                if (group.Value.ValueKind != JsonValueKind.Object
                    || !group.Value.TryGetProperty("template", out var templateValue)
                    || templateValue.ValueKind != JsonValueKind.String
                    || !group.Value.TryGetProperty("choices", out var choices)
                    || choices.ValueKind != JsonValueKind.Object)
                    continue;
                foreach (var choice in choices.EnumerateObject())
                {
                    var label = templateValue.GetString() ?? choice.Name;
                    if (choice.Value.ValueKind == JsonValueKind.Array)
                    {
                        var index = 0;
                        foreach (var argument in choice.Value.EnumerateArray())
                        {
                            var text = argument.ValueKind == JsonValueKind.String
                                ? argument.GetString() ?? string.Empty
                                : argument.GetRawText();
                            label = label.Replace("{" + index + "}", text, StringComparison.Ordinal);
                            index++;
                        }
                    }
                    detailLabels[choice.Name] = label;
                }
            }
        foreach (var item in available.EnumerateArray())
        {
            var id = item.GetString() ?? "";
            if (id.Length == 0) continue;
            labels[id] = detailLabels.TryGetValue(id, out var label) ? label : id;
        }
        return labels;
    }

    private static ModelUsage Usage(JsonElement root)
    {
        if (!root.TryGetProperty("usage", out var usage))
            return new ModelUsage(0, 0, 0);
        var input = usage.TryGetProperty("input_tokens", out var inputValue) ? inputValue.GetInt64() : 0;
        var output = usage.TryGetProperty("output_tokens", out var outputValue) ? outputValue.GetInt64() : 0;
        Require(input >= 0 && output >= 0);
        return new ModelUsage(input, output, 0);
    }

    private static bool HasAny(string value, params string[] terms) => terms.Any(value.Contains);

    private static bool IsTrue(string? value) => value is "1" or "true" or "TRUE" or "yes" or "YES";

    private static Uri ParseLoopbackBase(string value)
    {
        var uri = new Uri(value, UriKind.Absolute);
        Require(uri.Scheme == "http" && (uri.Host is "127.0.0.1" or "localhost") && uri.UserInfo.Length == 0
            && uri.Query.Length == 0 && uri.Fragment.Length == 0 && (uri.AbsolutePath is "/" or ""));
        return new Uri(uri.ToString().TrimEnd('/') + "/", UriKind.Absolute);
    }

    private static string PinnedIdentifier(string value)
    {
        Require(value.Length is >= 1 and <= 128);
        foreach (var ch in value)
            Require(char.IsAsciiLetterOrDigit(ch) || ch is '.' or '-' or '_' or ':' or '/');
        return value;
    }

    private static double ParseThreshold(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return DefaultThreshold;
        Require(double.TryParse(value, System.Globalization.NumberStyles.Float,
            System.Globalization.CultureInfo.InvariantCulture, out var parsed));
        Require(double.IsFinite(parsed) && parsed >= 0.5 && parsed <= 1);
        return parsed;
    }

    private static void Require(bool valid)
    {
        if (!valid) throw new InvalidOperationException("localjev_validation_failed");
    }

    public void Dispose()
    {
        _http.Dispose();
        _cloud.Dispose();
    }

    private sealed record RouteResult(string SelectedRoute, double RouteConfidence, bool RouterFallback,
        string? RouterFallbackReason, string RouterModel, string SelectedModel);

    private sealed record RouteMetadata(RouteResult Route, double? DecisionConfidence, bool CloudFallback,
        string? FallbackReason, string FinalModel)
    {
        public string Serialize() => JsonSerializer.Serialize(new
        {
            source = "localjev",
            router_model = Route.RouterModel,
            route = Route.SelectedRoute,
            route_confidence = Route.RouteConfidence,
            router_fallback = Route.RouterFallback,
            router_fallback_reason = Route.RouterFallbackReason,
            decision_confidence = DecisionConfidence,
            cloud_fallback = CloudFallback,
            fallback_reason = FallbackReason,
            selected_model = Route.SelectedRoute == LocalRoutine ? Route.SelectedModel : FinalModel,
            final_model = FinalModel,
        }, WireJson);
    }
}
