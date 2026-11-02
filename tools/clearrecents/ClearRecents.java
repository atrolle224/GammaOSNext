// Clears Android's Recents list, as "Clear all" does, when run as root:
//   CLASSPATH=clearrecents.dex app_process / ClearRecents
// Reflection only, so it builds against nothing and works across Android versions.
public final class ClearRecents {
    public static void main(String[] args) throws Exception {
        Class<?> atm = Class.forName("android.app.ActivityTaskManager");
        Object service = atm.getMethod("getService").invoke(null);
        service.getClass().getMethod("removeAllVisibleRecentTasks").invoke(service);
        System.out.println("recents cleared");
    }
}
