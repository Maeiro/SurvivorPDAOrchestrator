"""Exercise the production loot ledger against a small, deterministic engine fixture."""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/loot-tests'
OUT.mkdir(parents=True, exist_ok=True)
stubs = {
    'se/krka/kahlua/vm/KahluaTable.java': '''
package se.krka.kahlua.vm;
public class KahluaTable extends java.util.HashMap<Object,Object> {
 public Object rawget(Object k){return get(k);} public void rawset(Object k,Object v){if(v==null)remove(k);else put(k,v);}
 public int len(){int n=0;while(containsKey(n+1))n++;return n;}
}''',
    'zombie/Lua/LuaManager.java': '''
package zombie.Lua;
public class LuaManager {public static final Platform platform=new Platform();
 public static class Platform {public se.krka.kahlua.vm.KahluaTable newTable(){return new se.krka.kahlua.vm.KahluaTable();}}}''',
    'zombie/iso/IsoGridSquare.java': '''
package zombie.iso;
public class IsoGridSquare {public int getX(){return 0;} public int getY(){return 0;} public int getZ(){return 0;}}''',
    'zombie/iso/IsoObject.java': '''
package zombie.iso;
public class IsoObject {
 public zombie.inventory.ItemContainer container; public boolean moved;
 private final se.krka.kahlua.vm.KahluaTable md=new se.krka.kahlua.vm.KahluaTable();
 public se.krka.kahlua.vm.KahluaTable getModData(){return md;}
 public IsoGridSquare getSquare(){return new IsoGridSquare();} public int getObjectIndex(){return 0;}
 public int getContainerCount(){return 1;} public zombie.inventory.ItemContainer getContainerByIndex(int i){return container;}
 public boolean isMovedThumpable(){return moved;} public void flagForHotSave(){}
}''',
    'zombie/characters/IsoGameCharacter.java': 'package zombie.characters; public class IsoGameCharacter {}',
    'zombie/characters/IsoPlayer.java': '''
package zombie.characters;
public class IsoPlayer extends IsoGameCharacter {public boolean isDead(){return false;}
 public zombie.iso.IsoGridSquare getSquare(){return new zombie.iso.IsoGridSquare();}
 public float getX(){return .5f;}public float getY(){return .5f;}public float getZ(){return 0;}}''',
    'zombie/inventory/InventoryItem.java': '''
package zombie.inventory;
public class InventoryItem {private final se.krka.kahlua.vm.KahluaTable md=new se.krka.kahlua.vm.KahluaTable();
 public se.krka.kahlua.vm.KahluaTable getModData(){return md;}}''',
    'zombie/inventory/types/InventoryContainer.java': '''
package zombie.inventory.types;
public class InventoryContainer extends zombie.inventory.InventoryItem {
 private final zombie.inventory.ItemContainer inventory=new zombie.inventory.ItemContainer();
 public zombie.inventory.ItemContainer getInventory(){return inventory;}
}''',
    'zombie/inventory/ItemContainer.java': '''
package zombie.inventory;
public class ItemContainer {
 public zombie.iso.IsoObject parent=new zombie.iso.IsoObject(); public boolean looted,full;
 private final java.util.ArrayList<InventoryItem> items=new java.util.ArrayList<>();
 public ItemContainer(){parent.container=this;}
 public Object getContainingItem(){return null;}public Object getCharacter(){return null;}
 public zombie.iso.IsoObject getParent(){return parent;}public java.util.ArrayList<InventoryItem> getItems(){return items;}
 public zombie.iso.IsoGridSquare getSourceGrid(){return parent.getSquare();}public boolean isHasBeenLooted(){return looted;}
 public void Remove(InventoryItem item){items.remove(item);}
}''',
    'zombie/inventory/ItemPickInfo.java': '''
package zombie.inventory;
public class ItemPickInfo {public enum Caller {DoRollItem}
 public static ItemPickInfo GetPickInfo(ItemContainer c,Caller a){return new ItemPickInfo();}
 protected void updateRoomDist(ItemPickerJava.ItemPickerRoom room){}
}''',
    'zombie/inventory/ItemPickerJava.java': '''
package zombie.inventory;
public class ItemPickerJava {
 public static final java.util.HashMap<String,ItemPickerRoom> rooms=new java.util.HashMap<>();
 public static final java.util.List<Float> chances=new java.util.ArrayList<>();public static boolean fail;
 public static class ItemPickerRoom {public java.util.HashMap<String,ItemPickerContainer> containers=new java.util.HashMap<>();}
 public static class ItemPickerContainer {public ItemPickerContainer junk;public boolean procedural;
  public java.util.ArrayList<ProceduralItem> proceduralItems; public float chance=100;}
 public static class ProceduralItem {public String name;}
 public static ItemPickerContainer getItemContainer(String room,String type,String name,boolean junk){return rooms.get(room).containers.get(type);}
 public static void updateOverlaySprite(zombie.iso.IsoObject object){}
 private static void doRollItemInternal(ItemPickInfo info,ItemPickerContainer dist,ItemContainer container,float density,
  zombie.characters.IsoGameCharacter player,boolean bags,ItemPickerRoom room,boolean junk){
  float chance=maeiro.survivorpdaorchestrator.NightLoot.scale(dist.chance,container,3);
  chances.add(chance);if(chance>0&&!container.full)container.getItems().add(new InventoryItem());
  if(fail)throw new IllegalStateException("distribution callback failed");
 }
}''',
    'zombie/network/GameClient.java': 'package zombie.network; public class GameClient {public static boolean client;}',
}
for name in ('IsoCompost', 'IsoDeadBody', 'IsoThumpable'):
    stubs[f'zombie/iso/objects/{name}.java'] = f'package zombie.iso.objects; public class {name} extends zombie.iso.IsoObject {{}}'
stubs['zombie/vehicles/BaseVehicle.java'] = 'package zombie.vehicles; public class BaseVehicle extends zombie.iso.IsoObject {}'
sources = []
for name, source in stubs.items():
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source, encoding='utf-8')
    sources.append(str(path))
sources += [str(ROOT / 'src/maeiro/survivorpdaorchestrator/NightLoot.java'), str(ROOT / 'tests/java/NightLootTest.java')]
subprocess.run(['javac', '--release', '17', '-d', str(OUT), *sources], check=True)
subprocess.run(['java', '-ea', '-cp', str(OUT), 'NightLootTest'], check=True)
