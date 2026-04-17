import type { Project, ProjectSummary } from "@prisma/client";

import { db } from "@/lib/db";
import { generateProjectSummary } from "@/lib/gemini";
import { calculateActivityScore, recencyStatus } from "@/lib/ranking";

type ProjectWithRelations = Project & {
  updates: { id?: string; content?: string; createdAt: Date }[];
  summary: ProjectSummary | null;
};

export async function refreshProjectState(projectId: string) {
  const project = await db.project.findUnique({
    where: { id: projectId },
    include: {
      updates: {
        select: {
          id: true,
          content: true,
          createdAt: true,
        },
        orderBy: { createdAt: "desc" },
      },
      summary: true,
    },
  });

  if (!project) {
    return null;
  }

  const activityScore = calculateActivityScore(project);
  const fallbackSummary = buildFallbackSummary(project);
  let summaryText = fallbackSummary;

  try {
    const generatedSummary = await generateProjectSummary({
      projectName: project.name,
      existingSummary: project.summary?.summaryText ?? null,
      updates: project.updates.map((update) => ({
        content: update.content ?? "",
        createdAt: update.createdAt,
      })),
    });

    if (generatedSummary) {
      summaryText = generatedSummary;
    }
  } catch (error) {
    console.error("Failed to generate Gemini summary", error);
  }

  await db.project.update({
    where: { id: projectId },
    data: {
      activityScore,
      lastUpdateAt: project.updates[0]?.createdAt ?? project.lastUpdateAt,
    },
  });

  await db.projectSummary.upsert({
    where: {
      projectId,
    },
    create: {
      projectId,
      summaryText,
      sourceUpdateCount: project.updates.length,
    },
    update: {
      summaryText,
      sourceUpdateCount: project.updates.length,
    },
  });

  return activityScore;
}

export function serializeProject(project: ProjectWithRelations) {
  return {
    id: project.id,
    name: project.name,
    lastUpdateAt: project.lastUpdateAt,
    activityScore: project.activityScore,
    recencyStatus: recencyStatus(project.lastUpdateAt),
    updateCount: project.updates.length,
    summary: project.summary?.summaryText ?? null,
  };
}

export function buildFallbackSummary(project: ProjectWithRelations) {
  if (project.updates.length === 0) {
    return "No updates yet. Add the first update to start tracking this project.";
  }

  const latestUpdate = project.updates[0];
  const bullets = project.updates
    .slice(0, 4)
    .map((update) => `- ${truncate(update.content ?? "", 140)}`)
    .join("\n");

  return [
    `Latest update: ${truncate(latestUpdate.content ?? "", 220)}`,
    "",
    "Recent notes:",
    bullets,
  ].join("\n");
}

function truncate(value: string, limit: number) {
  if (value.length <= limit) {
    return value;
  }

  return `${value.slice(0, limit - 1).trimEnd()}…`;
}
