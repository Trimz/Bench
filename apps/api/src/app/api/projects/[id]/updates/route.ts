import { NextResponse } from "next/server";
import { z } from "zod";

import { db } from "@/lib/db";
import { jsonError } from "@/lib/http";
import { refreshProjectState } from "@/lib/projects";
import { requireCurrentUser } from "@/lib/route-auth";

const createUpdateSchema = z.object({
  content: z.string().trim().min(1).max(4000),
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
  const project = await db.project.findFirst({
    where: {
      id,
      userId: auth.user.id,
    },
    select: {
      id: true,
    },
  });

  if (!project) {
    return jsonError("Project not found.", 404);
  }

  const updates = await db.projectUpdate.findMany({
    where: {
      projectId: id,
    },
    orderBy: {
      createdAt: "desc",
    },
  });

  return NextResponse.json({ updates });
}

export async function POST(request: Request, { params }: Params) {
  const auth = await requireCurrentUser();

  if ("error" in auth) {
    return auth.error;
  }

  const { id } = await params;
  const project = await db.project.findFirst({
    where: {
      id,
      userId: auth.user.id,
    },
    select: {
      id: true,
    },
  });

  if (!project) {
    return jsonError("Project not found.", 404);
  }

  const body = await request.json().catch(() => null);
  const parsed = createUpdateSchema.safeParse(body);

  if (!parsed.success) {
    return jsonError("Invalid update payload.", 422);
  }

  const update = await db.projectUpdate.create({
    data: {
      projectId: id,
      content: parsed.data.content,
    },
  });

  await refreshProjectState(id);

  return NextResponse.json({ update }, { status: 201 });
}
