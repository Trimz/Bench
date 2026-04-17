import { NextResponse } from "next/server";
import { z } from "zod";

import { getCurrentUser } from "@/lib/auth";
import { db } from "@/lib/db";
import { jsonError } from "@/lib/http";
import { calculateActivityScore, recencyStatus } from "@/lib/ranking";

const createProjectSchema = z.object({
  name: z.string().trim().min(1).max(120),
});

export async function GET() {
  const user = await getCurrentUser();

  if (!user) {
    return jsonError("Unauthorized.", 401);
  }

  const projects = await db.project.findMany({
    where: {
      userId: user.id,
    },
    include: {
      updates: {
        select: { createdAt: true },
        orderBy: { createdAt: "desc" },
        take: 20,
      },
      summary: true,
    },
  });

  const rankedProjects = projects
    .map((project) => {
      const activityScore = calculateActivityScore(project);

      return {
        id: project.id,
        name: project.name,
        lastUpdateAt: project.lastUpdateAt,
        activityScore,
        recencyStatus: recencyStatus(project.lastUpdateAt),
        updateCount: project.updates.length,
        summary: project.summary?.summaryText ?? null,
      };
    })
    .sort((left, right) => right.activityScore - left.activityScore);

  return NextResponse.json({ projects: rankedProjects });
}

export async function POST(request: Request) {
  const user = await getCurrentUser();

  if (!user) {
    return jsonError("Unauthorized.", 401);
  }

  const body = await request.json().catch(() => null);
  const parsed = createProjectSchema.safeParse(body);

  if (!parsed.success) {
    return jsonError("Invalid project payload.", 422);
  }

  const project = await db.project.create({
    data: {
      userId: user.id,
      name: parsed.data.name,
    },
    select: {
      id: true,
      name: true,
      createdAt: true,
      updatedAt: true,
    },
  });

  return NextResponse.json({ project }, { status: 201 });
}
