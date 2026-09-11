using System.Runtime.CompilerServices;
using System.Text.Json;
using Godot;
using OpenGameAgent;
using OpenGameAgent.Godot;
using OpenGameAgent.Kernel;

// The official node owns worker dispatch, bounded signal delivery and cancellation.
// This host only configures it. It has no reference to the world writer or GM.
public partial class OgaResidentNode : OpenGameAgentNode
{
    private GameAgentRuntime? _ownedRuntime;
    private BudgetGatewayProvider? _gatewayProvider;
    private string _provenance = "opengameagent_fixture";

    public string NewOperationId() => Guid.NewGuid().ToString();
    public string CurrentProvenance() => _provenance;

    public string SetupGateway(string configPath)
    {
        try
        {
            if (_ownedRuntime != null) return "already_configured";
            _gatewayProvider = new BudgetGatewayProvider(configPath);
            _provenance = _gatewayProvider.Provenance;
            // Request the exact model the run config pinned; no host default here.
            SetupRuntime(_gatewayProvider, _gatewayProvider.ModelId);
            return "";
        }
        catch
        {
            _gatewayProvider?.Dispose();
            _gatewayProvider = null;
            return "gateway_configuration_rejected";
        }
    }

    public void Setup(string fixtureMode = "normal")
    {
        SetupRuntime(new ObservationFixtureProvider(fixtureMode), "offline-observation-fixture");
    }

    private void SetupRuntime(IModelProvider provider, string model)
    {
        if (_ownedRuntime != null) throw new InvalidOperationException("Already configured.");
        _ownedRuntime = new GameAgentRuntime(new GameAgentRuntimeOptions(
            provider, model)
        {
            Instructions = "You are one resident. Only use your supplied personal observations and experiences. " +
                "Propose one available action as JSON: action, reason, optionally need {capability_id, reason} when waiting. " +
                "You cannot invent resources, change world rules, install capabilities, or command other residents.",
            ExecutionScopeProvider = (_, _) => new ValueTask<GameExecutionScope>(GameExecutionScope.NoOptionalCapabilities),
            AgentLimits = new AgentLimits { MaxTurns = 1, MaxMessages = 48, MaxToolCallsPerTurn = 1 },
            Limits = new GameRuntimeLimits { MaxConcurrentActors = 1, MaxQueuedInputsPerActor = 1, MaxInputJsonCharacters = 16000 },
            ModelParameters = new ModelParameters { MaxOutputTokens = 512 },
            ContextWindowTokens = 8192,
            ContextWindowReserveTokens = 512,
        });
        Configure(_ownedRuntime, maximumConcurrentRuns: 1, maximumQueuedSignals: 64, maximumSignalsPerFrame: 32);
    }

    public override void _ExitTree()
    {
        base._ExitTree();
        _ownedRuntime?.Dispose();
        _ownedRuntime = null;
        _gatewayProvider?.Dispose();
        _gatewayProvider = null;
    }

    // Deterministic integration fixture, deliberately NOT an LLM or paid provider.
    // It exercises the actual upstream runtime and uses only its model-visible input.
    private sealed class ObservationFixtureProvider(string mode) : IModelProvider
    {
        public async IAsyncEnumerable<ModelStreamEvent> StreamAsync(ModelRequest request,
            [EnumeratorCancellation] CancellationToken cancellationToken)
        {
            await Task.Delay(mode == "timeout" ? Timeout.Infinite : 35, cancellationToken);
            if (mode == "failure") throw new InvalidOperationException("fixture_provider_failure");
            var input = request.Messages.Last(m => m.Role == AgentRole.User).Content.OfType<JsonContent>().First();
            using var document = JsonDocument.Parse(input.Json);
            var root = document.RootElement;
            var payload = root.TryGetProperty("payload", out var camel) ? camel : root.GetProperty("Payload");
            var view = payload.GetProperty("resident_view");
            var available = view.GetProperty("available_actions").EnumerateArray().Select(a => a.GetString()).ToArray();
            object decision = available.Contains("drink_water")
                ? new { action = "drink_water", reason = "I have water and I am thirsty." }
                : available.Contains("draw_water")
                    ? new { action = "draw_water", reason = "I can see a working bucket." }
                    : new { action = "wait", reason = "I cannot safely draw water." };
            var needs = view.GetProperty("needs");
            if (!available.Contains("draw_water") && !available.Contains("drink_water") &&
                needs.GetProperty("thirst").GetInt32() > 0 && needs.GetProperty("capability_request").ValueKind == JsonValueKind.Null)
                decision = new { action = "wait", reason = "I need a way to reach the water.",
                    need = new { capability_id = "well_bucket", reason = "I am thirsty but cannot safely draw water." } };
            // Adversarial fixture: an available action is an option, not an obligation.
            if (mode == "defer-use" && available.Contains("draw_water") && !available.Contains("drink_water"))
                decision = new { action = "wait", reason = "The bucket works, but I choose to wait for now." };
            var json = mode == "malformed" ? "not-json" : JsonSerializer.Serialize(decision);
            yield return ModelStreamEvent.Terminal(new ModelResponse(
                new AgentContent[] { new TextContent(json) }, ModelStopReason.Stop,
                provider: "fixture", responseModel: "offline-observation-fixture"));
        }
    }
}
