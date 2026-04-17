type ProjectForRanking = {
  lastUpdateAt: Date | null;
  updates: { createdAt: Date }[];
};

const DAY_MS = 1000 * 60 * 60 * 24;

export function recencyStatus(lastUpdateAt: Date | null) {
  if (!lastUpdateAt) {
    return "red" as const;
  }

  const ageInDays = (Date.now() - lastUpdateAt.getTime()) / DAY_MS;

  if (ageInDays <= 3) {
    return "green" as const;
  }

  if (ageInDays <= 10) {
    return "yellow" as const;
  }

  return "red" as const;
}

export function calculateActivityScore(project: ProjectForRanking) {
  if (!project.lastUpdateAt) {
    return 0;
  }

  const ageInDays = (Date.now() - project.lastUpdateAt.getTime()) / DAY_MS;
  const recentUpdates = project.updates.filter(
    (update) => Date.now() - update.createdAt.getTime() <= DAY_MS * 14,
  ).length;

  const freshnessBoost = ageInDays <= 3 ? 100 : Math.max(0, 60 - ageInDays * 4);
  const recentVolumeBoost = recentUpdates * 12;
  const resurfacingBoost = ageInDays >= 14 ? Math.min(40, (ageInDays - 14) * 2) : 0;

  return Number((freshnessBoost + recentVolumeBoost + resurfacingBoost).toFixed(2));
}
