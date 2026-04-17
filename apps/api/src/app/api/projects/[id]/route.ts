import { NextResponse } from "next/server";
import { z } from "zod";

import { getOwnedProject, requireCurrentUser } from "@/lib/route-auth";
import { serializeProject } from "@/lib/projects";
import { db } from "@/lib/db";
import { jsonError } from "@/lib/http";

const patchProjectSchema = z.object({
  name: z.string().trim().min(1).max(120),
});

type Params = {
  params: Promise<{ id: string }>;
};

export async function GET(_: Request, { params }: Params) {
  const auth = await requireCurrentUser();

  if ("error" in auth) {
    return auth.error;
  }

  const { id } = await params;
  const project = await getOwnedProject(auth.user.id, id);

  if (!project) {
    return jsonError("Project not found.", 404);
  }

  return NextResponse.json({
    project: serializeProject(project),
  });
}

export async function PATCH(request: Request, { params }: Params) {
  const auth = await requireCurrentUser();

  if ("error" in auth) {
    return auth.error;
  }

  const body = await request.json().catch(() => null);
  const parsed = patchProjectSchema.safeParse(body);

  if (!parsed.success) {
    return jsonError("Invalid project payload.", 422);
  }

  const { id } = await params;
  const existingProject = await db.project.findFirst({
    where: {
      id,
      userId: auth.user.id,
    },
  });

  if (!existingProject) {
    return jsonError("Project not found.", 404);
  }

  const project = await db.project.update({
    where: {
      id,
    },
    data: {
      name: parsed.data.name,
    },
    include: {
      updates: {
        select: { createdAt: true },
        orderBy: { createdAt: "desc" },
      },
      summary: true,
    },
  });

  return NextResponse.json({
    project: serializeProject(project),
  });
}
