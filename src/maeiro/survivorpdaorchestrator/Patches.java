package maeiro.survivorpdaorchestrator;

import me.zed_0xff.zombie_buddy.Patch;

public final class Patches {
    private Patches() {
    }

    @Patch(className = "zombie.gameStates.IngameState", methodName = "enter", warmUp = true)
    public static class ExposeLuaBridge {
        @Patch.OnEnter
        public static void enter() {
            Bridge.initialize();
        }
    }

    @Patch(className = "zombie.inventory.ItemPickerJava", methodName = "fillContainer", warmUp = true)
    public static class NightLootFill {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(0) Object container, @Patch.Argument(1) Object player,
                @Patch.Local("spdoLootFill") Object context) {
            context = NightLoot.begin(container);
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(@Patch.Local("spdoLootFill") Object context, @Patch.Thrown Throwable failure) {
            NightLoot.finish(context, failure);
        }
    }

    @Patch(className = "zombie.inventory.ItemPickerJava", methodName = "doRollItemInternal", warmUp = true)
    public static class NightLootDistribution {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(0) Object info, @Patch.Argument(1) Object distribution,
                @Patch.Argument(2) Object container, @Patch.Argument(3) float density,
                @Patch.Argument(4) Object player, @Patch.Argument(5) boolean bags,
                @Patch.Argument(6) Object room, @Patch.Argument(7) boolean junk) {
            NightLoot.capture(container, distribution, density, bags, room, junk);
        }
    }

    @Patch(className = "zombie.inventory.ItemPickerJava", methodName = "getActualSpawnChance", warmUp = true)
    public static class NightLootChance {
        @Patch.OnExit
        public static void exit(@Patch.Argument(2) Object container, @Patch.Return(readOnly = false) float result) {
            result = Bridge.scaleNightLootChance(result, container);
        }
    }

}
