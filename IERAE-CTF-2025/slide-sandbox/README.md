# slide-sandbox

## Challenge Description

A XSS challenge by `y0d3n`. It is a Fastify application with two static HTML pages, and the vulnerability is on the client-side.

## Challenge Source code

The vulnerable source code is here:

```html
<body>
  <h1 class="title" id="title"></h1><br>
  <div class="game-area">
    <div class="puzzle-container" id="puzzle">
      <iframe id="frame0" sandbox="allow-same-origin"></iframe>
      <iframe id="frame1" sandbox="allow-same-origin"></iframe>
      <iframe id="frame2" sandbox="allow-same-origin"></iframe>
      <iframe id="frame3" sandbox="allow-same-origin"></iframe>
      <iframe id="frame4" sandbox="allow-same-origin"></iframe>
      <iframe id="frame5" sandbox="allow-same-origin"></iframe>
      <iframe id="frame6" sandbox="allow-same-origin"></iframe>
      <iframe id="frame7" sandbox="allow-same-origin"></iframe>
      <iframe id="frame8" sandbox="allow-same-origin"></iframe>
    </div>
    <div class="message">
      <a href="/">TOP</a>
    </div>
  </div>
</body>

<script>
  let pieces = Array();
  fetch('/puzzles/' + (new URLSearchParams(location.search)).get('id'))
    .then(r => r.json())
    .then(puzzle => {
      document.getElementById('title').innerText = puzzle.title;

      const ans = puzzle.answers.split('').sort(() => Math.random() - 0.5); // Sometimes the puzzles are impossible. Forgive please.      
      ans.forEach((v, i) => {
        pieces.push(document.createElement("div"));
      })
      pieces.push(document.createElement("div"))

      for (var i = 0; i < frames.length; i++) {
        frames[i].addEventListener("click", slide);
        frames[i].document.body.appendChild(pieces[i]);
      }

      ans.forEach((v, i) => {
        pieces[i].innerHTML = puzzle.template.replaceAll("{{v}}", v);
      })
    });

  function slide(e) {
    // ...
  };
</script>

```

With the server-side code:

```js
const schema = {
  body: {
    type: "object",
    properties: {
      title: { type: "string", maxLength: 100 },
      template: { type: "string", maxLength: 1000 },
      answers: { type: "string", minLength: 8, maxLength: 8 },
    },
    required: ["title", "template", "answers"],
  },
};

app.post("/create", { schema }, (req, reply) => {
  const title = req.body.title;
  const template = req.body.template.replaceAll("\r", "").replaceAll("\n", "");
  const answers = req.body.answers;

  const puzzle = db.createPuzzle(req.user, {
    title,
    template,
    answers,
  });

  return reply.redirect(`/puzzle?id=${puzzle.id}`);
});
```

## What did I do?

### Stuggle

Solving this parallel with `canvasbox`, it seems that this one, although tagged `easy`, is not that `easy`. There must be something simple that I missed?

There are two things that looks sus on this frontend source code:

- `fetch('/puzzles/' + (new URLSearchParams(location.search)).get('id'))`
    - This allows a path transversal and adding query string which absolutely not helpful for solving this challenge.
- `ans.forEach((v, i) => {` and `for (var i = 0; i < frames.length; i++) {`
    - For some reason there is a inconsistency here. Why?

Looked around the backend query string parsing libraries and the fastify middlewares with no result.


## Solution

After reading the postmortem chat  in the fastify schema `"😀".length == 1`, while on the frontend `"😀".split('').length == 2`, so we can increase the length of `ans` to more than 8.

If it is more than 8, there would be some `div` not binding to a `iframe`, and have their `innerHTML` set. It turns out that, the script inside them would run even before a element inserted to the document (NB: `<script>` tag won't work). So this would pop an alert box:

```js
document.createElement("div").innerHTML = "<img src=y onerror=alert(1) />"
```

### TIL

It seems that in many cases, `<script>` tag won't work but `<img src=x onerror />` would. I did tried the effect of `ans.length > 8`, but I have used `<script>` tag for the test, so I thought the script didn't run :/

Anyway, the emojis 😀😀😀 is always fanscating and easy to miss. Hopefully I can solve these `easy` challenges next time. Thanks for the fun challenge!