import { getEnv } from "@/lib/env";

type GeminiResponse = {
  candidates?: Array<{
    content?: {
      parts?: Array<{
        text?: string;
      }>;
    };
  }>;
};

export async function generateProjectSummary(input: {
  projectName: string;
  existingSummary?: string | null;
  updates: Array<{ content: string; createdAt: Date }>;
}) {
  const env = getEnv();

  if (!env.GEMINI_API_KEY) {
    return null;
  }

  const model = env.GEMINI_MODEL ?? "gemini-2.5-flash";
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

  const latestUpdates = input.updates.slice(0, 8).map((update, index) => {
    return `${index + 1}. ${update.createdAt.toISOString()} - ${update.content}`;
  });

  const prompt = [
    `Project: ${input.projectName}`,
    input.existingSummary ? `Existing summary:\n${input.existingSummary}` : "Existing summary: none",
    "",
    "Recent project updates:",
    latestUpdates.length > 0 ? latestUpdates.join("\n") : "No updates yet.",
    "",
    "Write a concise factual summary of the current project state.",
    "Requirements:",
    "- 2 short paragraphs maximum",
    "- focus on what changed, current direction, and open momentum",
    "- do not use bullet points",
    "- do not invent facts",
  ].join("\n");

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": env.GEMINI_API_KEY,
    },
    body: JSON.stringify({
      system_instruction: {
        parts: [
          {
            text: "You summarize project status updates for a productivity app. Be concise, factual, and cumulative.",
          },
        ],
      },
      contents: [
        {
          parts: [
            {
              text: prompt,
            },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.4,
      },
    }),
  });

  if (!response.ok) {
    throw new Error(`Gemini request failed with status ${response.status}.`);
  }

  const data = (await response.json()) as GeminiResponse;
  const text = data.candidates?.[0]?.content?.parts?.map((part) => part.text ?? "").join("").trim();

  return text || null;
}
