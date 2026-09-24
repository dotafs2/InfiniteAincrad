import type { Answer, JsonValue } from "./types";

export const ROUTE_CLASSES = [
  "local_routine",
  "cloud_social",
  "cloud_story_critical",
  "gm_review",
] as const;

export type RouteClass = (typeof ROUTE_CLASSES)[number];

export interface RouteCandidate {
  model: string;
  route_class: RouteClass;
}

export type RouteState = string | JsonValue[] | { [key: string]: JsonValue };

export interface RouteRequest {
  state: RouteState;
  task_type: string;
  irreversible?: boolean;
  scarce_resource?: boolean;
  story_critical?: boolean;
  multi_party?: boolean;
  requires_dialogue?: boolean;
  candidates?: RouteCandidate[];
}

export interface RouteResult {
  selected_model: string;
  selected_route: RouteClass;
  route_confidence: number;
  fallback: boolean;
  fallback_reason: string | null;
  router_model: string;
}

const DEFAULT_CANDIDATES: RouteCandidate[] = [
  { model: "qwen3:8b", route_class: "local_routine" },
  { model: "kimi-k2.6", route_class: "cloud_social" },
  { model: "kimi-k2.6", route_class: "cloud_story_critical" },
  { model: "deepseek-gm", route_class: "gm_review" },
];

function validModel(model: string): boolean {
  return /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(model);
}

export function candidatesOrDefault(candidates?: RouteCandidate[]): RouteCandidate[] {
  const value = candidates?.length ? candidates : DEFAULT_CANDIDATES;
  if (value.length > 16) throw new Error("At most 16 route candidates are allowed");
  if (candidates?.length) {
    for (const routeClass of ROUTE_CLASSES) {
      if (!value.some((candidate) => candidate.route_class === routeClass)) {
        throw new Error(`Route candidates must include ${routeClass}`);
      }
    }
  }
  for (const candidate of value) {
    if (!validModel(candidate.model)) throw new Error("Route candidate model is invalid");
    if (!ROUTE_CLASSES.includes(candidate.route_class)) {
      throw new Error("Route candidate class is invalid");
    }
  }
  return value;
}

function confidence(answer: Answer | undefined): number {
  if (!answer || answer.type !== "choice") return 0;
  return answer.confidence;
}

export function chooseRoute(
  answer: Answer | undefined,
  request: RouteRequest,
  routerModel: string,
): RouteResult {
  const candidates = candidatesOrDefault(request.candidates);
  const modelChoice = answer?.type === "choice" ? answer.choice : "";
  const routeConfidence = confidence(answer);
  const forcedClass: RouteClass | null = request.story_critical
    ? "cloud_story_critical"
    : request.irreversible || request.scarce_resource || request.multi_party
      ? "gm_review"
      : request.requires_dialogue
        ? "cloud_social"
      : null;
  const safeModel = (routeClass: RouteClass): string =>
    candidates.find((candidate) => candidate.route_class === routeClass)!.model;

  if (forcedClass) {
    return {
      selected_model: safeModel(forcedClass),
      selected_route: forcedClass,
      route_confidence: 1,
      fallback: true,
      fallback_reason: `policy_forced_${forcedClass}`,
      router_model: routerModel,
    };
  }

  const selected = ROUTE_CLASSES.includes(modelChoice as RouteClass)
    ? (modelChoice as RouteClass)
    : "local_routine";
  if (routeConfidence < 0.75 || !answer || answer.type !== "choice") {
    return {
      selected_model: safeModel("cloud_social"),
      selected_route: "cloud_social",
      route_confidence: routeConfidence,
      fallback: true,
      fallback_reason: "router_confidence_below_0_75",
      router_model: routerModel,
    };
  }
  return {
    selected_model: safeModel(selected),
    selected_route: selected,
    route_confidence: routeConfidence,
    fallback: false,
    fallback_reason: null,
    router_model: routerModel,
  };
}

export function routeQuestion(taskType: string, request: RouteRequest) {
  return {
    type: "choice" as const,
    instructions: {
      task_type: taskType,
      goal: "Choose the execution route, not the final resident action.",
      local_routine: "Short routine reasoning with no story, contract, scarce resource, or multi-party consequence.",
      cloud_social: "Natural dialogue or social reasoning where a richer model is useful.",
      cloud_story_critical: "Story-critical, canon-sensitive, or irreversible narrative reasoning.",
      gm_review: "World rule, contract, scarce resource, or multi-party change requiring authoritative review.",
      current_state: request.state,
    },
    criteria: {
      local_routine: "Use the local model for a bounded routine turn.",
      cloud_social: "Use the cloud social model for nuanced dialogue or social reasoning.",
      cloud_story_critical: "Use the cloud story model for story-critical reasoning.",
      gm_review: "Use the GM model for authoritative world-impacting reasoning.",
    },
  };
}
