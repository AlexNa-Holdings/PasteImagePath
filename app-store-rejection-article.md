# My App Got Rejected by Apple. So I Open-Sourced It Instead.

I built a tiny Mac utility called **Paste Image Path**.

It is especially useful when working with AI CLI tools in Terminal.  
Normally, you can’t just paste an image directly into a terminal prompt.  
With this utility, you copy an image, press one shortcut, and instantly get a file path you can paste into the CLI.

That’s it. Fast, simple, useful.

And Apple rejected it.

## The app in one sentence

Paste Image Path turns a clipboard image into a file path and pastes it into your active app, so you don’t have to do the manual 7-step dance of saving, finding, right-clicking, copying path, switching windows, and pasting.

## Why users liked it

Because it removes friction. A lot of friction.

Especially if you:
- work with docs, markdown, CMS editors, tickets, or dev tools all day
- hate context switching
- prefer keyboard workflows
- have motor strain and want fewer repetitive actions

It also lets you view previous pastes and reuse them quickly, so repeating common image references is effortless.

This wasn’t “nice to have.” It saved time every single day.

## Why Apple said no

On **February 23, 2026**, and again on **March 5, 2026**, App Review rejected version 1.0 under Guideline **2.4.5**.

Their position: the app requests Accessibility permissions but “does not use these features for accessibility purposes,” and specifically they flagged usage related to hotkey/paste behavior.

My position: this *is* an accessibility improvement, because it compresses multiple precise, repetitive actions into one shortcut, and macOS offers no clean sandboxed alternative for cross-app paste injection.

Result: still rejected.

## The fun part (or tragic comedy part)

I wrote a careful, respectful explanation.  
I clarified scope.  
I explained the accessibility intent.  
I offered to add clearer in-app messaging.

Apple replied, essentially: “Issue remains.”

So yes, apparently reducing repetitive hand motion is not accessibility enough when done by a small indie utility with good manners.

## What now

The app is **not** in the Mac App Store.  
But it is still alive, useful, and open source.
GitHub: https://github.com/AlexNa-Holdings/PasteImagePath

If you want practical tools built by people who actually use them, this one is for you.

No cloud.  
No tracking.  
No weird growth hacks.  
Just: copy image, hit shortcut, get path, move on with your day.

## Final thought

I get that platform rules are complicated and safety matters.  
But when policy interpretation blocks simple quality-of-life tools, users lose.

So this is my official pivot:  
From “please approve my utility” to “here’s the source code, enjoy.”

And honestly?  
That feels better already.
