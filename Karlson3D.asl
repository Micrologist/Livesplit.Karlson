state("Karlson"){}

startup
{
    vars.gameTarget = new SigScanTarget("48 83 EC 08 48 89 34 24 48 8B F1 48 B8 ?? ?? ?? ?? ?? ?? 00 00 48 89 30 C6 46 ?? 00 48 8B 34 24 48 83 C4 08 C3");
    vars.gameStartTarget = new SigScanTarget("8B EC 48 83 EC 30 48 89 75 F8 48 8B F1 C6 46 18 01 C6 46 19 00 F3 0F 10 05 71 00 00 00 F3 0F 5A C0 F2 0F 5A C0 48 8D AD 00 00 00 00 49 BB ?? ?? ?? ?? ?? ?? 00 00 41 FF D3 48 B8 ?? ?? ?? ?? ?? ?? 00 00 48 8B 00 48 8B C8 83 38 00 49 BB ?? ?? ?? ?? ?? ?? 00 00 41 FF D3 48 B8 ?? ?? ?? ?? ?? ?? 00 00 48 8B 00 48 8B C8 83 39 00 C6 40 24 00 66 0F 57 C0 F2 0F 5A E8 F3 0F 11 68 20 48 8B 75 F8 48 8D 65 00 5D C3");
    vars.previousTime = 0f;
    vars.doStart = false;
    vars.inTutorial = true;

    Func<float, float> RoundTime = (time) => {
        var f = Math.Round(time * 100)/100;
        return (float)f;
    };
    vars.RoundTime = RoundTime;
    vars.ignoreTimer = true;
    vars.initCooldown = new Stopwatch();

    if (timer.CurrentTimingMethod == TimingMethod.RealTime) {        
    	var timingMessage = MessageBox.Show (
       		"This game uses Game Time (IGT) as the main timing method.\n"+
    		"LiveSplit is currently set to show Real Time (RTA).\n"+
    		"Would you like to set the timing method to IGT?",
       		 "Karlson 3D | LiveSplit",
       		MessageBoxButtons.YesNo,MessageBoxIcon.Question
       	);
		
        if (timingMessage == DialogResult.Yes) {
		timer.CurrentTimingMethod = TimingMethod.GameTime;
        }
	}
}

init
{
    vars.timerFound = false;
    var gamePtr = IntPtr.Zero;
    
    if(!vars.initCooldown.IsRunning)
    {
        vars.initCooldown.Start();
    }

    var timeSinceLastInit = vars.initCooldown.Elapsed.TotalMilliseconds;

    if(timeSinceLastInit >= 1000)
    {
        foreach (var page in game.MemoryPages(true))
        {
            var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
            if(gamePtr == IntPtr.Zero)
                gamePtr = scanner.Scan(vars.gameTarget);
            if(gamePtr != IntPtr.Zero)
            break;
        }

        if(gamePtr == IntPtr.Zero)
        {
            vars.initCooldown.Restart();
            throw new Exception("game pointer not found - resetting");
        }
        else
        {
            vars.initCooldown.Reset();
        }
    }
    else
    {
        throw new Exception("init not ready");
    }
    
    print("game pointer found");
    vars.doStart = false;
    var doneptr = new DeepPointer(gamePtr+0xD, 0x0, 0x19);
    vars.done = new MemoryWatcher<bool>(doneptr);
    var playingptr = new DeepPointer(gamePtr+0xD, 0x0, 0x18);
    vars.playing = new MemoryWatcher<bool>(playingptr);

    vars.watchers = new MemoryWatcherList() { vars.playing, vars.done };
}



update
{
    vars.watchers.UpdateAll(game);

    if(!vars.timerFound && vars.playing.Current)
    {
        var startPtr = IntPtr.Zero;
        foreach (var page in game.MemoryPages(true))
		{
			var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
			if(startPtr == IntPtr.Zero)
                startPtr = scanner.Scan(vars.gameStartTarget);

            if(startPtr != IntPtr.Zero)
                break;
		}

        if(startPtr != IntPtr.Zero)
        {
            print("start pointer found");
            var timerptr = new DeepPointer(startPtr+0x5b, 0x0, 0x20);
            vars.timer = new MemoryWatcher<float>(timerptr);
            vars.watchers = new MemoryWatcherList() { vars.playing, vars.done, vars.timer };
            vars.timerFound = true;
            vars.doStart = true;
        }
    }

    if(!vars.timerFound)
        return false;


    if((vars.timer.Current < vars.timer.Old) && !vars.ignoreTimer)
    {
        vars.previousTime += vars.RoundTime(vars.timer.Old);
    }
}

start
{
    vars.previousTime = 0f;
    vars.ignoreTimer = true;

    if((vars.playing.Current && !vars.playing.Old) || vars.doStart || (vars.timer.Current < vars.timer.Old))
    {
        vars.doStart = false;
        vars.inTutorial = true;
        return true;
    }
}

reset
{
    if (vars.inTutorial && (vars.timer.Current < vars.timer.Old))
        return true;
}

split
{
    vars.ignoreTimer = false;
    if(vars.done.Current && !vars.done.Old)
    {
        vars.inTutorial = false;
        return true;
    }
}


isLoading { return true; }

gameTime
{  
    return TimeSpan.FromSeconds(vars.RoundTime(vars.timer.Current) + vars.previousTime);
}
