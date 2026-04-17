import { NextResponse } from "next/server";

import { db } from "@/lib/db";
import { jsonError } from "@/lib/http";
import { refreshProjectState, serializeProject } from "@/lib/projects";
import { requireCurrentUser } from "@/lib/route-auth";

type RouteContext = {
  params: Promise<Record<string, string | string[] | undefined>>;
};

export async function POST(_: Request, { params }: RouteContext) {
  const auth = await requireCurrentUser();

  if ("error" in auth) {
    return auth.error;
  }

  const routeParams = await params;
  const id = typeof routeParams.id === "string" ? routeParams.id : null;

  if (!id) {
    return jsonError("Project not found.", 404);
  }

  const project = await db.project.findFirst({
    where: {
      id,
      userId: auth.user.id,
    },
    include: {
      updates: {
        orderBy: { createdAt: "desc" },
      },
      summary: true,
    },
  });

  if (!project) {
    return jsonError("Project not found.", 404);
  }

  await refreshProjectState(project.id);

  const refreshedProject = await db.project.findUnique({
    where: { id: project.id },
    include: {
      updates: {
        orderBy: { createdAt: "desc" },
      },
      summary: true,
    },
  });

  return NextResponse.json({
    project: refreshedProject ? serializeProject(refreshedProject) : null,
  });
}
