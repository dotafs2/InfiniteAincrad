using System;
using System.Collections.Generic;
using System.Text.Json;
using Godot;

// Legacy history contains doubles for which Godot's decimal parser changes the
// last bit. System.Text.Json provides round-trip numeric parsing and formatting.
// No new package: this is part of the project's existing .NET runtime.
public partial class TownJsonCodec : RefCounted
{
    // Deterministic lifetime: callers must capture the Decode/Encode result and
    // then call Release() so the managed RefCounted wrapper is disposed before
    // native engine teardown instead of surviving to the finalizer queue.
    public void Release() => Dispose();

    public Variant Decode(string text)
    {
        try
        {
            using var document = JsonDocument.Parse(text);
            return Read(document.RootElement);
        }
        catch (JsonException) { return default; }
    }

    public string Encode(Godot.Collections.Dictionary state) =>
        JsonSerializer.Serialize(Write(state));

    private static Variant Read(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Object => ReadObject(value),
        JsonValueKind.Array => ReadArray(value),
        JsonValueKind.String => value.GetString()!,
        JsonValueKind.Number => value.TryGetInt64(out long number) ? Variant.From(number) : Variant.From(value.GetDouble()),
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        _ => default,
    };

    private static Godot.Collections.Dictionary ReadObject(JsonElement value)
    {
        var result = new Godot.Collections.Dictionary();
        foreach (var property in value.EnumerateObject())
            result[property.Name] = Read(property.Value);
        return result;
    }

    private static Godot.Collections.Array ReadArray(JsonElement value)
    {
        var result = new Godot.Collections.Array();
        foreach (var item in value.EnumerateArray()) result.Add(Read(item));
        return result;
    }

    private static object? Write(Variant value) => value.VariantType switch
    {
        Variant.Type.Nil => null,
        Variant.Type.Bool => value.AsBool(),
        Variant.Type.Int => value.AsInt64(),
        Variant.Type.Float => value.AsDouble(),
        Variant.Type.String => value.AsString(),
        Variant.Type.Dictionary => WriteObject(value.AsGodotDictionary()),
        Variant.Type.Array => WriteArray(value.AsGodotArray()),
        _ => throw new InvalidOperationException("Unsupported non-JSON world value"),
    };

    private static Dictionary<string, object?> WriteObject(Godot.Collections.Dictionary value)
    {
        var result = new Dictionary<string, object?>();
        foreach (var pair in value) result.Add(pair.Key.AsString(), Write(pair.Value));
        return result;
    }

    private static List<object?> WriteArray(Godot.Collections.Array value)
    {
        var result = new List<object?>();
        foreach (var item in value) result.Add(Write(item));
        return result;
    }
}
