package maeiro.survivorpdaorchestrator;

import me.zed_0xff.zombie_buddy.Exposer;

public final class Bridge {
    private static volatile float nightLootMultiplier = 1.0f;

    static {
        Exposer.exposeClass(Bridge.class, "SurvivorPDAOrchestratorBridge");
    }

    private Bridge() {
    }

    public static void initialize() {
    }

    public static void setNightLootState(boolean active, int lootBonusPercent) {
        int bonus = Math.max(0, Math.min(500, lootBonusPercent));
        nightLootMultiplier = active ? 1.0f + bonus / 100.0f : 1.0f;
    }

    public static float nightLootMultiplier() {
        return nightLootMultiplier;
    }

    public static float scaleNightLootChance(float chance, Object container) {
        return NightLoot.scale(chance, container, nightLootMultiplier);
    }

    public static void setNightLootMode(int mode) {
        NightLoot.setMode(mode);
    }

    public static void setNightLootDiagnosticLogging(boolean enabled) {
        NightLoot.setDiagnosticLogging(enabled);
    }

    public static boolean inspectNightLoot(Object container, Object player, int percent) {
        return NightLoot.inspect(container, player, percent);
    }

    public static Object beginNightLootRefresh(Object container) {
        return NightLoot.beginRefresh(container);
    }

    public static void finishNightLootRefresh(Object context, boolean success) {
        NightLoot.finishRefresh(context, success);
    }

    public static String nightLootDiagnostics() {
        return NightLoot.diagnostics();
    }

}
