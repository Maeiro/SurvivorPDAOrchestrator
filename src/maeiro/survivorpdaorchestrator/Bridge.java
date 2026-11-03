package maeiro.survivorpdaorchestrator;

import me.zed_0xff.zombie_buddy.Exposer;

public final class Bridge {
    private static volatile float nightLootMultiplier = 1.0f;

    static {
        Exposer.exposeClass(Bridge.class, "SurvivorPDAOrchestratorBridge");
    }

    private Bridge() {
    }

    public static void setNightLootState(boolean active, int lootBonusPercent) {
        int bonus = Math.max(0, Math.min(500, lootBonusPercent));
        nightLootMultiplier = active ? 1.0f + bonus / 100.0f : 1.0f;
    }

    public static float scaleNightLootChance(float chance, Object container) {
        return container == null ? chance : chance * nightLootMultiplier;
    }

}
