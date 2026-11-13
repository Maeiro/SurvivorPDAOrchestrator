package maeiro.survivorpdaorchestrator;

import java.lang.reflect.Method;
import java.lang.reflect.InvocationTargetException;
import java.util.ArrayList;
import java.util.ArrayDeque;
import java.util.Collections;
import java.util.HashMap;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.ItemPickInfo;
import zombie.inventory.ItemPickerJava;
import zombie.inventory.ItemPickerJava.ItemPickerContainer;
import zombie.inventory.ItemPickerJava.ItemPickerRoom;
import zombie.inventory.types.InventoryContainer;
import zombie.iso.IsoObject;
import zombie.iso.objects.IsoCompost;
import zombie.iso.objects.IsoDeadBody;
import zombie.iso.objects.IsoThumpable;
import zombie.network.GameClient;
import zombie.vehicles.BaseVehicle;

public final class NightLoot {
    private static final String KEY = "SPDO_NightLoot";
    private static final ThreadLocal<Fill> filling = new ThreadLocal<>();
    private static final ThreadLocal<Bonus> bonus = new ThreadLocal<>();
    private static final ThreadLocal<Refresh> refreshing = new ThreadLocal<>();
    private static final IdentityHashMap<ItemPickerContainer, String> distributionIds = new IdentityHashMap<>();
    private static final Map<String, ItemPickerContainer> distributions = new HashMap<>();
    private static final IdentityHashMap<ItemPickerRoom, String> roomIds = new IdentityHashMap<>();
    private static Object registryRoot;
    private static int registryProceduralCount = -1;
    private static Method roll;
    private static Method updateRoom;
    private static volatile int mode = 1;
    private static volatile boolean diagnosticLogging;
    private static long generated, inspected, rewarded, skipped, failures;
    private static String lastReason = "Ready";

    private NightLoot() {
    }

    private static final class Fill {
        final ItemContainer container;
        final Fill previous;
        final List<InventoryItem> before;
        final KahluaTable data;
        boolean nativeBonus;

        Fill(ItemContainer container, Fill previous) {
            this.container = container;
            this.previous = previous;
            this.before = new ArrayList<>(container.getItems());
            this.data = table();
            data.rawset("version", 1.0);
            data.rawset("rolls", table());
        }
    }

    private static final class Bonus {
        final ItemContainer container;
        final float factor;

        Bonus(ItemContainer container, float factor) {
            this.container = container;
            this.factor = factor;
        }
    }

    private static final class Refresh {
        final ItemContainer container;
        final Object saved;
        final Refresh previous;

        Refresh(ItemContainer container) {
            this.container = container;
            this.saved = state(container);
            this.previous = refreshing.get();
        }
    }

    public static void setMode(int value) {
        mode = value == 2 ? 2 : 1;
    }

    public static void setDiagnosticLogging(boolean enabled) {
        diagnosticLogging = enabled;
    }

    public static boolean eligible(ItemContainer container) {
        if (container == null || container.getContainingItem() != null || container.getCharacter() != null) return false;
        IsoObject object = container.getParent();
        if (object == null || object.getSquare() == null || object.getObjectIndex() < 0
                || object instanceof IsoThumpable || object instanceof IsoDeadBody
                || object instanceof BaseVehicle || object instanceof IsoCompost || object.isMovedThumpable()) return false;
        KahluaTable md = object.getModData();
        if (Boolean.TRUE.equals(md.rawget("ExtractionModeNoRefresh"))) return false;
        ArrayDeque<ItemContainer> pending = new ArrayDeque<>();
        Set<ItemContainer> seen = Collections.newSetFromMap(new IdentityHashMap<>());
        pending.add(container);
        while (!pending.isEmpty()) {
            ItemContainer current = pending.removeFirst();
            if (!seen.add(current)) continue;
            for (InventoryItem item : current.getItems()) {
                KahluaTable imd = item.getModData();
                if (imd.rawget("ExtractionModeQuestRaidId") != null || imd.rawget("ExtractionModeQuestItemId") != null
                        || imd.rawget("ExtractionModeFlareRaidId") != null) return false;
                if (item instanceof InventoryContainer bag) pending.add(bag.getInventory());
            }
        }
        return containerIndex(container) >= 0;
    }

    public static float scale(float chance, Object value, float multiplier) {
        if (!(value instanceof ItemContainer container)) return chance;
        Bonus extra = bonus.get();
        if (extra != null) return chance * (extra.container == container ? extra.factor : 1.0f);
        Fill fill = filling.get();
        if (mode == 1 && fill != null && fill.container == container) return chance;
        if (fill != null && fill.container == container && multiplier > 1) fill.nativeBonus = true;
        return chance * multiplier;
    }

    public static Object begin(Object value) {
        try {
            if (GameClient.client || bonus.get() != null || !(value instanceof ItemContainer container) || !eligible(container)) return null;
            Fill fill = new Fill(container, filling.get());
            filling.set(fill);
            return fill;
        } catch (Exception | LinkageError error) {
            failed(error);
            return null;
        }
    }

    public static void capture(Object value, Object distribution, float density, boolean bags, Object room, boolean junk) {
        Fill fill = filling.get();
        if (fill == null || fill.container != value || bonus.get() != null) return;
        try {
            registry();
            String id = distributionIds.get(distribution);
            if (id == null || (room != null && !roomIds.containsKey(room))) {
                fill.data.rawset("unsupported", true);
                return;
            }
            KahluaTable entry = table();
            entry.rawset("distribution", id);
            entry.rawset("room", roomIds.get(room));
            entry.rawset("density", (double) density);
            entry.rawset("bags", bags);
            entry.rawset("junk", junk);
            KahluaTable entries = (KahluaTable) fill.data.rawget("rolls");
            entries.rawset(entries.len() + 1, entry);
        } catch (Exception | LinkageError error) {
            fill.data.rawset("unsupported", true);
            failed(error);
        }
    }

    public static void finish(Object context, Throwable error) {
        if (!(context instanceof Fill fill)) return;
        filling.set(fill.previous);
        if (error != null) return;
        try {
            KahluaTable previous = state(fill.container);
            // Vanilla respawn attempts can succeed without adding anything. They do not renew eligibility.
            Refresh refresh = refreshing.get();
            if (previous != null && fill.before.equals(fill.container.getItems())
                    && (refresh == null || refresh.container != fill.container)) return;
            fill.data.rawset("inspected", false);
            fill.data.rawset("nativeBonus", fill.nativeBonus);
            putState(fill.container, fill.data);
            generated++;
            if (diagnosticLogging && mode == 2 && fill.nativeBonus) {
                log("generation bonus=" + Math.max(0, Math.round((Bridge.nightLootMultiplier() - 1.0f) * 100))
                        + "% distributions=" + ((KahluaTable) fill.data.rawget("rolls")).len()
                        + " added=" + addedCount(fill.container, fill.before) + " " + location(fill.container));
            }
        } catch (Exception | LinkageError failure) {
            failed(failure);
        }
    }

    public static Object beginRefresh(Object value) {
        if (!(value instanceof ItemContainer container)) return null;
        Refresh context = new Refresh(container);
        refreshing.set(context);
        return context;
    }

    public static void finishRefresh(Object value, boolean success) {
        if (!(value instanceof Refresh context)) return;
        refreshing.set(context.previous);
        if (!success) putState(context.container, context.saved);
    }

    public static boolean inspect(Object value, Object character, int percent) {
        if (GameClient.client || !(value instanceof ItemContainer container) || !(character instanceof IsoPlayer player)) return false;
        try {
            if (!eligible(container) || player.isDead() || player.getSquare() == null
                    || player.getZ() != container.getSourceGrid().getZ()
                    || Math.abs(player.getX() - (container.getSourceGrid().getX() + 0.5f)) > 3
                    || Math.abs(player.getY() - (container.getSourceGrid().getY() + 0.5f)) > 3) return false;
            KahluaTable data = state(container);
            if (data == null || !(data.rawget("version") instanceof Number version) || version.intValue() != 1) return skip("NoHistory", percent, container);
            if (Boolean.TRUE.equals(data.rawget("inspected"))) return false;
            if (container.isHasBeenLooted()) {
                markInspected(data, container);
                return skip("AlreadyLooted", percent, container);
            }
            if (mode != 1 || percent <= 0 || Boolean.TRUE.equals(data.rawget("nativeBonus"))) {
                markInspected(data, container);
                return false;
            }
            if (Boolean.TRUE.equals(data.rawget("unsupported"))) {
                markInspected(data, container);
                return skip("NoDistribution", percent, container);
            }
            registry();
            KahluaTable entries = (KahluaTable) data.rawget("rolls");
            if (entries == null || entries.len() == 0) {
                markInspected(data, container);
                return skip("NoDistribution", percent, container);
            }
            List<ItemPickerContainer> resolved = new ArrayList<>();
            List<ItemPickerRoom> rooms = new ArrayList<>();
            for (int i = 1; i <= entries.len(); i++) {
                KahluaTable entry = (KahluaTable) entries.rawget(i);
                ItemPickerContainer dist = distributions.get(entry.rawget("distribution"));
                String roomId = (String) entry.rawget("room");
                ItemPickerRoom room = roomId == null ? null : ItemPickerJava.rooms.get(roomId);
                if (dist == null || (roomId != null && room == null)) {
                    markInspected(data, container);
                    return skip("NoDistribution", percent, container);
                }
                resolved.add(dist);
                rooms.add(room);
            }
            if (roll == null) {
                // The public doRollItem overload loses the junk flag; retain native junk and item configuration rules.
                roll = ItemPickerJava.class.getDeclaredMethod("doRollItemInternal", ItemPickInfo.class,
                        ItemPickerContainer.class, ItemContainer.class, float.class, IsoGameCharacter.class,
                        boolean.class, ItemPickerRoom.class, boolean.class);
                roll.setAccessible(true);
                updateRoom = ItemPickInfo.class.getDeclaredMethod("updateRoomDist", ItemPickerRoom.class);
                updateRoom.setAccessible(true);
            }
            markInspected(data, container);
            List<InventoryItem> before = new ArrayList<>(container.getItems());
            try {
                for (int remaining = Math.min(500, percent); remaining > 0; remaining -= 100) {
                    bonus.set(new Bonus(container, Math.min(100, remaining) / 100.0f));
                    for (int i = 1; i <= entries.len(); i++) {
                        KahluaTable entry = (KahluaTable) entries.rawget(i);
                        ItemPickInfo info = ItemPickInfo.GetPickInfo(container, ItemPickInfo.Caller.DoRollItem);
                        if (info != null) updateRoom.invoke(info, rooms.get(i - 1));
                        roll.invoke(null, info, resolved.get(i - 1), container, ((Number) entry.rawget("density")).floatValue(),
                                player, Boolean.TRUE.equals(entry.rawget("bags")), rooms.get(i - 1), Boolean.TRUE.equals(entry.rawget("junk")));
                    }
                }
            } catch (Exception | LinkageError failure) {
                for (InventoryItem item : new ArrayList<>(container.getItems())) {
                    if (!before.contains(item)) container.Remove(item);
                }
                data.rawset("inspected", false);
                container.getParent().flagForHotSave();
                throw failure;
            } finally {
                bonus.remove();
            }
            rewarded++;
            lastReason = "Applied";
            if (diagnosticLogging) {
                log("inspection bonus=" + percent + "% distributions=" + entries.len()
                        + " added=" + addedCount(container, before) + " " + location(container));
            }
            ItemPickerJava.updateOverlaySprite(container.getParent());
            return !before.equals(container.getItems());
        } catch (Exception | LinkageError failure) {
            failed(failure);
            return false;
        }
    }

    public static String diagnostics() {
        return generated + "/" + inspected + "/" + rewarded + "/" + skipped + "/" + failures + " (" + lastReason + ")";
    }

    private static boolean skip(String reason, int percent, ItemContainer container) {
        skipped++;
        if (diagnosticLogging) log("inspection skipped=" + reason + " bonus=" + percent + "% " + location(container));
        lastReason = reason;
        return false;
    }

    private static void markInspected(KahluaTable data, ItemContainer container) {
        data.rawset("inspected", true);
        container.getParent().flagForHotSave();
        inspected++;
    }

    private static void failed(Throwable failure) {
        failures++;
        while (failure instanceof InvocationTargetException && failure.getCause() != null) failure = failure.getCause();
        String reason = failure.getClass().getSimpleName() + ": " + failure.getMessage();
        if (!reason.equals(lastReason)) System.out.println("[Survivor PDA Orchestrator] Night loot operation failed: " + reason);
        lastReason = reason;
    }

    private static int addedCount(ItemContainer container, List<InventoryItem> before) {
        int count = 0;
        for (InventoryItem item : container.getItems()) if (!before.contains(item)) count++;
        return count;
    }

    private static String location(ItemContainer container) {
        IsoObject object = container == null ? null : container.getParent();
        if (object == null || object.getSquare() == null) return "container=" + (container == null ? "unknown" : container.getType());
        return "container=" + container.getType() + " at=" + object.getX() + "," + object.getY() + "," + object.getZ();
    }

    private static void log(String message) {
        System.out.println("[Survivor PDA Orchestrator] Night loot diagnostic: " + message);
    }

    private static KahluaTable table() {
        return LuaManager.platform.newTable();
    }

    private static int containerIndex(ItemContainer container) {
        IsoObject object = container.getParent();
        if (object == null) return -1;
        for (int i = 0; i < object.getContainerCount(); i++) {
            if (object.getContainerByIndex(i) == container) return i;
        }
        return -1;
    }

    private static KahluaTable state(ItemContainer container) {
        Object records = container.getParent().getModData().rawget(KEY);
        return records instanceof KahluaTable entries && entries.rawget(Integer.toString(containerIndex(container))) instanceof KahluaTable data
                ? data : null;
    }

    private static void putState(ItemContainer container, Object data) {
        IsoObject object = container.getParent();
        Object saved = object.getModData().rawget(KEY);
        KahluaTable entries = saved instanceof KahluaTable t ? t : table();
        entries.rawset(Integer.toString(containerIndex(container)), data);
        object.getModData().rawset(KEY, entries);
        object.flagForHotSave();
    }

    private static void register(String id, ItemPickerContainer dist) {
        if (dist == null) return;
        distributionIds.putIfAbsent(dist, id);
        distributions.put(id, dist);
        if (dist.junk != null) register(id + "/junk", dist.junk);
    }

    private static void registry() {
        Object all = ItemPickerJava.rooms.get("all");
        int proceduralCount = ItemPickerJava.ProceduralDistributions.size();
        if (all == registryRoot && proceduralCount == registryProceduralCount && !distributionIds.isEmpty()) return;
        distributionIds.clear();
        distributions.clear();
        roomIds.clear();
        for (Map.Entry<String, ItemPickerRoom> entry : ItemPickerJava.rooms.entrySet()) {
            roomIds.put(entry.getValue(), entry.getKey());
            for (Map.Entry<String, ItemPickerContainer> dist : entry.getValue().containers.entrySet()) {
                register("room/" + entry.getKey() + "\n" + dist.getKey(), dist.getValue());
            }
        }
        for (Object value : ItemPickerJava.ProceduralDistributions.entrySet()) {
            if (value instanceof Map.Entry<?, ?> entry && entry.getKey() instanceof String id
                    && entry.getValue() instanceof ItemPickerContainer dist) {
                register("proc/" + id, dist);
            }
        }
        registryRoot = all;
        registryProceduralCount = proceduralCount;
    }
}
