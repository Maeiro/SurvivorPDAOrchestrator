package maeiro.survivorpdaorchestrator;

import me.zed_0xff.zombie_buddy.Patch;

public final class Patches {
    private Patches() {
    }

    @Patch(className = "zombie.inventory.ItemPickerJava", methodName = "getActualSpawnChance", warmUp = true)
    public static class NightLootChance {
        @Patch.OnExit
        public static void exit(@Patch.Argument(2) Object container, @Patch.Return(readOnly = false) float result) {
            result = Bridge.scaleNightLootChance(result, container);
        }
    }

}
