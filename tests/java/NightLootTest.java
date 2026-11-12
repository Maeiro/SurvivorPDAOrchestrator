import maeiro.survivorpdaorchestrator.NightLoot;
import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.ItemPickerJava;
import zombie.inventory.ItemPickerJava.ItemPickerContainer;
import zombie.inventory.ItemPickerJava.ItemPickerRoom;

public class NightLootTest {
    private static final IsoPlayer PLAYER = new IsoPlayer();
    private static final ItemPickerContainer DIST = new ItemPickerContainer();
    private static final ItemPickerRoom ROOM = new ItemPickerRoom();
    private static int checks;

    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
        checks++;
    }

    private static void fill(ItemContainer c, boolean add, boolean fail) {
        Object context = NightLoot.begin(c);
        NightLoot.capture(c, DIST, 0, true, ROOM, false);
        check(NightLoot.scale(10, c, 3) == 10, "inspection mode does not multiply native chances");
        if (add) c.getItems().add(new InventoryItem());
        NightLoot.finish(context, fail ? new IllegalStateException("fill failed") : null);
    }

    public static void main(String[] args) {
        ROOM.containers.put("crate", DIST);
        ItemPickerJava.rooms.put("all", ROOM);
        for (int percent : new int[]{0, 50, 150, 200}) {
            ItemContainer c = new ItemContainer();
            fill(c, true, false);
            InventoryItem original = c.getItems().get(0);
            ItemPickerJava.chances.clear();
            NightLoot.inspect(c, PLAYER, percent);
            check(c.getItems().contains(original), "original loot preserved");
            check(ItemPickerJava.chances.size() == (percent + 99) / 100, "correct number of extra passes");
            if (percent == 50 || percent == 150) {
                check(ItemPickerJava.chances.get(ItemPickerJava.chances.size() - 1) == 50, "fractional pass uses half chances");
            }
            int count = c.getItems().size();
            NightLoot.inspect(c, new IsoPlayer(), 200);
            check(c.getItems().size() == count, "another player or reopening cannot repeat bonus");
        }
        ItemContainer day = new ItemContainer();
        fill(day, true, false);
        NightLoot.inspect(day, PLAYER, 0);
        check(!NightLoot.inspect(day, PLAYER, 200), "daytime inspection consumes eligibility");
        fill(day, true, false);
        check(NightLoot.inspect(day, PLAYER, 200), "real native refill renews eligibility");
        fill(day, false, false);
        check(!NightLoot.inspect(day, PLAYER, 200), "empty vanilla respawn attempt does not renew eligibility");
        Object refresh = NightLoot.beginRefresh(day);
        day.getItems().clear();
        fill(day, false, false);
        NightLoot.finishRefresh(refresh, true);
        check(NightLoot.inspect(day, PLAYER, 200), "successful empty Extraction refresh renews eligibility");
        refresh = NightLoot.beginRefresh(day);
        day.getItems().clear();
        fill(day, true, false);
        NightLoot.finishRefresh(refresh, false);
        check(!NightLoot.inspect(day, PLAYER, 200), "rolled-back Extraction refresh restores consumed state");
        check(!NightLoot.inspect(new ItemContainer(), PLAYER, 200), "legacy container without history is preserved");
        ItemContainer full = new ItemContainer();
        fill(full, true, false);
        full.full = true;
        check(!NightLoot.inspect(full, PLAYER, 200), "full container receives no items");
        full.full = false;
        check(!NightLoot.inspect(full, PLAYER, 200), "emptying a full container cannot retry bonus");
        ItemContainer zero = new ItemContainer();
        DIST.chance = 0;
        fill(zero, false, false);
        check(!NightLoot.inspect(zero, PLAYER, 200), "rarity None stays empty");
        DIST.chance = 100;
        ItemContainer failure = new ItemContainer();
        fill(failure, true, true);
        check(!NightLoot.inspect(failure, PLAYER, 200), "failed native generation is not registered");
        fill(failure, true, false);
        int before = failure.getItems().size();
        ItemPickerJava.fail = true;
        check(!NightLoot.inspect(failure, PLAYER, 200), "failed bonus reports no change");
        check(failure.getItems().size() == before, "failed bonus removes only its additions");
        ItemPickerJava.fail = false;
        check(!NightLoot.inspect(failure, PLAYER, 200), "failed bonus cannot be rerolled by reopening");
        check(NightLoot.scale(10, failure, 3) == 30, "bonus multiplier context is restored after failure");
        ItemContainer looted = new ItemContainer();
        fill(looted, true, false);
        looted.looted = true;
        check(!NightLoot.inspect(looted, PLAYER, 200), "already looted container is protected");
        ItemContainer moved = new ItemContainer();
        moved.parent.moved = true;
        check(!NightLoot.eligible(moved), "moved storage excluded");
        ItemContainer quest = new ItemContainer();
        zombie.inventory.types.InventoryContainer bag = new zombie.inventory.types.InventoryContainer();
        InventoryItem questItem = new InventoryItem();
        questItem.getModData().rawset("ExtractionModeQuestRaidId", 1);
        bag.getInventory().getItems().add(questItem);
        quest.getItems().add(bag);
        check(!NightLoot.eligible(quest), "quest items inside bags protect the outer container");
        ItemContainer legacy = new ItemContainer();
        NightLoot.setMode(2);
        Object context = NightLoot.begin(legacy);
        NightLoot.capture(legacy, DIST, 0, true, ROOM, false);
        check(NightLoot.scale(10, legacy, 3) == 30, "legacy mode multiplies original chance");
        legacy.getItems().add(new InventoryItem());
        NightLoot.finish(context, null);
        NightLoot.setMode(1);
        check(!NightLoot.inspect(legacy, PLAYER, 200), "switching modes does not apply a second bonus");
        System.out.println("NightLootTest: " + checks + " assertions passed");
    }
}
