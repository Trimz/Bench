import { getCurrentUser } from "@/lib/auth";
import { db } from "@/lib/db";
import { jsonError } from "@/lib/http";

export async function requireCurrentUser() {
  const user = await getCurrentUser();

  if (!user) {
    return { error: jsonError("Unauthorized.", 401) } as const;
  }

  return { user } as const;
}

export async function getOwnedProject(userId: string, projectId: string) {
  return db.project.findFirst({
    where: {
      id: projectId,
      userId,
    },
    include: {
      updates: {
        orderBy: { createdAt: "desc" },
      },
      summary: true,
    },
  });
}
