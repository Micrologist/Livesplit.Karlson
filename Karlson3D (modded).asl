state("Karlson"){}

startup
{
    vars.gameTarget = new SigScanTarget("48 83 EC 08 48 89 34 24 48 8B F1 48 B8 ?? ?? ?? ?? ?? ?? 00 00 48 89 30 C6 46 20 00 48 8B 34 24 48 83 C4 08 C3");
    vars.previousTime = 0f;
    vars.doStart = false;
    vars.doReset = false;
}

init
{
    var ptr = IntPtr.Zero;
    while (ptr == IntPtr.Zero)
    {
        foreach (var page in game.MemoryPages(true))
		{
			var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
			if(ptr == IntPtr.Zero)
				ptr = scanner.Scan(vars.gameTarget);
			else
				break;
		}
        if (ptr == IntPtr.Zero)
            Thread.Sleep(1000);
    }

    print("game pointer found");

    var timerptr = new DeepPointer(ptr+0xD, 0x0, 0x18, 0x20);
    vars.timer = new MemoryWatcher<float>(timerptr);
    var levelIDptr = new DeepPointer(ptr+0xD, 0x0, 0x24);
    vars.levelID = new MemoryWatcher<int>(levelIDptr);
    var doneptr = new DeepPointer(ptr+0xD, 0x0, 0x21);
    vars.done = new MemoryWatcher<bool>(doneptr);

    vars.watchers = new MemoryWatcherList() { vars.timer, vars.levelID, vars.done };
}

update
{
    vars.watchers.UpdateAll(game);
}

start
{
    vars.previousTime = 0f;
    if((vars.levelID.Current == 2 && vars.levelID.Old != 2) || vars.doStart)
    {
        vars.doStart = false;
        return true;
    }
}

split
{
    if(vars.done.Current && !vars.done.Old)
    {
        return true;
    }

    if(vars.timer.Current < vars.timer.Old)
    {
        vars.previousTime += vars.timer.Old;
        if(vars.levelID.Current == 2)
        {
            vars.doReset = true;
            vars.doStart = true;
        }
    }
}

isLoading
{
    return true;
}

gameTime
{  
    return TimeSpan.FromSeconds(vars.timer.Current + vars.previousTime);
}

reset
{
    if (vars.doReset)
    {
        vars.doReset = false;
        return true;
    }
}
