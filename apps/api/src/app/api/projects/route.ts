import { NextResponse } from "next/server";
import { z } from "zod";

import { db } from "@/lib/db";
import { jsonError } from "@/lib/http";
import { refreshProjectState, serializeProject } from "@/lib/projects";
import { requireCurrentUser } from "@/lib/route-auth";

const createProjectSchema = z.object({
  name: z.string().trim().min(1).max(120),
});

export async function GET() {
  const auth = await requireCurrentUser();

  if ("error" in auth) {
    return auth.error;
  }

  const projects = await db.project.findMany({
    where: {
      userId: auth.user.id,
    },
    include: {
      updates: {
        orderBy: { createdAt: "desc" },
        take: 20,
      },
      summary: true,
    },
  });

  const rankedProjects = projects
    .map(serializeProject)
    .sort((left, right) => right.activityScore - left.activityScore);

  return NextResponse.json({ projects: rankedProjects });
}

export async function POST(request: Request) {
  const auth = await requireCurrentUser();

  if ("error" in auth) {
    return auth.error;
  }

  const body = await request.json().catch(() => null);
  const parsed = createProjectSchema.safeParse(body);

  if (!parsed.success) {
    return jsonError("Invalid project payload.", 422);
  }

  const project = await db.project.create({
    data: {
      userId: auth.user.id,
      name: parsed.data.name,
    },
    include: {
      updates: true,
      summary: true,
    },
  });

  await refreshProjectState(project.id);

  return NextResponse.json({ project: serializeProject(project) }, { status: 201 });
}
