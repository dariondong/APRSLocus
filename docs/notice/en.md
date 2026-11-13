# Audit complete: updates resumed (v2.2.0)

The unauthorised commits of 12 November 2026 have been fully audited. Result: the injected build pipeline never executed, and no build-time secret was ever read. v2.2.0 has been rebuilt with a **new signing certificate**, and updates can resume.

**Severity: resolved · Last updated 12 November 2026, 18:20 (UTC+8)**

## 1. Audit result

- The injected pipeline was triggered by v* tags. Each injection existed for only about 48 seconds before a ci: restore commit reverted it, and no build was ever triggered by it.
- Build-time secrets (the signing certificate and the object-storage keys) were therefore never read. The earlier statement that the signing keys had been exposed was incorrect.
- The unauthorised commits and decoy pull requests are gone; no leftover files remain, and the workflows are byte-identical to their pre-incident state.

## 2. This build requires a clean install

- Out of caution the signing certificate is still treated as potentially compromised, so it has been replaced and reissued.
- **The signature changed, so this build cannot be installed over an older one.** Export a backup, uninstall the old version, then install v2.2.0.
- The new certificate's SHA-1 and SHA-256 are listed below for you to verify.

## 3. Releases and verification

- v2.2.0 and later are signed with the new certificate.
- Use only the SHA-256 values published on the official site and GitHub Releases.
**New signing certificate fingerprints**

SHA-1:   BE:7C:EC:BA:1C:8F:9B:78:64:9A:2E:03:5C:D7:62:9E:BA:B1:4A:0C
SHA-256: 0F:2C:52:7A:9C:D6:6A:43:A8:71:F3:51:92:C7:5C:B7:5F:C1:B8:5B:6F:63:BA:45:8C:B5:A9:82:0A:2E:38:8A

- The old signature (v2.1.43 and earlier) is retired. Any future "new version" carrying the old signature should be treated as forged.

## 4. What we will never do

- We will never ask for your password or verification code through any channel.
- We will never ask to remotely control your device.

## 5. Channels

- Website: [aprslocus.theez.top](https://aprslocus.theez.top)
- Feedback and reports: [GitHub Issues](https://github.com/dariondong/APRSLocus/issues)
- Trusted builds and checksums come from official channels only. Do not forward unverified packages or patches.

---

## APRSNETCN OA · #261113

APRSNETCN OA is a weekly APRS message roll call run by APRSNET.CN.

@video https://aprsnet.cn/oa/embed.html

### 1. When

13 November 2026, 00:00–23:59 Beijing time (UTC+8).

Other zones: UTC 16:00 on 12 November to 15:59 on 13 November; Japan (UTC+9) 01:00 on 13 November to 00:59 on 14 November; India (UTC+5:30) 21:30 on 12 November to 21:29 on 13 November; US Eastern (EST, UTC-5) 11:00 on 12 November to 10:59 on 13 November.

### 2. Duty callsign

**BG7LMW-6** (ChenJiaMing).

The duty callsign changes every week. The site's page for the current week is the one to read.

@video https://aprsnet.cn/oa/en/embed.html

### 3. How to check in

- Send an APRS message to **BG7LMW-6** with the body **CQ CNNET**, your own call and your own grid, for example **CQ CNNET BG7XXX OL62**. A grid of 4 or 6 characters both work, and the call in the body is your own.
- When the ACK arrives, send a new message to **BG7LMW-6** with **U CNNET** alone.
- Optional: add a sentence after the grid, for example **CQ CNNET BG7XXX OL62 weekend on the hill**. The roster gains a message row.

### 4. Two ways in

- Over the network (APRS-IS): connect a phone or a computer to a server and send.
- Over the air (RF): send from a handheld or a mobile rig, and a nearby gateway carries it into the network.

Both count. RF counts more.

### 5. Worth knowing

- The message recipient is **BG7LMW-6**, and the call in the body is your own. Do not mix the two up.
- After the ACK, send a separate **U CNNET**. Do not reply on top of the ACK.
- One send that day is enough. Sending again adds no row.
- An extra sentence does not change whether the check-in counts.
- Transmit under your own call and licence, on the frequency and path your local rules allow.

Activity page: **[Open the activity page](https://oa.aprsnet.cn)**

13 November: one CQ out, one ACK in, one U back.

**APRSNET.CN**

---

## APRSNETCN OA · #261107

APRSNETCN OA is a weekly APRS message roll call run by APRSNET.CN.

### 1. When

Saturday, 7 November 2026, 00:00–23:59 Beijing time (UTC+8).

Other zones: UTC 16:00 on 6 November to 15:59 on 7 November; Japan (UTC+9) 01:00 on 7 November to 00:59 on 8 November; India (UTC+5:30) 21:30 on 6 November to 21:29 on 7 November; US Eastern (EST, UTC-5) 11:00 on 6 November to 10:59 on 7 November.

### 2. Duty callsign

**BD3QID-6** (无锡焊铅丝).

The duty callsign changes every week. The site's page for the current week is the one to read.

@video https://aprsnet.cn/oa/en/embed.html

### 3. How to check in

- Send an APRS message to **BD3QID-6** with the body **CQ CNNET**, your own call and your own grid, for example **CQ CNNET BG7XXX OL62**. A grid of 4 or 6 characters both work, and the call in the body is your own.
- When the ACK arrives, send a new message to **BD3QID-6** with **U CNNET** alone.
- Optional: add a sentence after the grid, for example **CQ CNNET BG7XXX OL62 weekend on the hill**. The roster gains a message row.

### 4. Two ways in

- Over the network (APRS-IS): connect a phone or a computer to a server and send.
- Over the air (RF): send from a handheld or a mobile rig, and a nearby gateway carries it into the network.

Both count. RF counts more.

### 5. Worth knowing

- The message recipient is **BD3QID-6**, and the call in the body is your own. Do not mix the two up.
- After the ACK, send a separate **U CNNET**. Do not reply on top of the ACK.
- One send that day is enough. Sending again adds no row.
- An extra sentence does not change whether the check-in counts.
- Transmit under your own call and licence, on the frequency and path your local rules allow.

### 6. A song

A new song from 星游记, the Chinese animation series. The song is 《再飞行！》, and a line from it runs 真正相信奇迹的家伙，本身就和奇迹一样了不起。

@video https://player.bilibili.com/player.html?isOutside=true&aid=117568270504061&bvid=BV1UB4v67Exr&cid=43375264631&p=1

Activity page: **[Open the activity page](https://oa.aprsnet.cn)**

Saturday, 7 November: one CQ out, one ACK in, one U back.

**APRSNET.CN**

---

## APRSNETCN OA · #261031

APRSNETCN OA is a weekly APRS message roll call run by APRSNET.CN.

### 1. When

Saturday, 31 October 2026, 00:00–23:59 Beijing time (UTC+8).

Other zones: UTC 16:00 on 30 October to 15:59 on 31 October; Japan (UTC+9) 01:00 on 31 October to 00:59 on 1 November; India (UTC+5:30) 21:30 on 30 October to 21:29 on 31 October; US Eastern (EDT, UTC-4) 12:00 on 30 October to 11:59 on 31 October.

### 2. Duty callsign

**BG7OSL-6** (ZhangZhanRui).

The duty callsign changes every week. The site's page for the current week is the one to read.

### 3. How to check in

- Send an APRS message to **BG7OSL-6** with the body **CQ CNNET**, your own call and your own grid, for example **CQ CNNET BG7XXX OL62**. A grid of 4 or 6 characters both work, and the call in the body is your own.
- When the ACK arrives, send a new message to **BG7OSL-6** with **U CNNET** alone.
- Optional: add a sentence after the grid, for example **CQ CNNET BG7XXX OL62 weekend on the hill**. The roster gains a message row.

### 4. Two ways in

- Over the network (APRS-IS): connect a phone or a computer to a server and send.
- Over the air (RF): send from a handheld or a mobile rig, and a nearby gateway carries it into the network.

Both count. RF counts more.

### 5. Worth knowing

- The message recipient is **BG7OSL-6**, and the call in the body is your own. Do not mix the two up.
- After the ACK, send a separate **U CNNET**. Do not reply on top of the ACK.
- One send that day is enough. Sending again adds no row.
- An extra sentence does not change whether the check-in counts.
- Transmit under your own call and licence, on the frequency and path your local rules allow.

Activity page: **[Open the activity page](https://oa.aprsnet.cn)**

Saturday, 31 October: one CQ out, one ACK in, one U back.

**APRSNET.CN**

## APRSNETCN OA · #261024 Half a Cat Bed

APRSNETCN OA is an APRS message check-in run by APRSNET.CN. It lasts a whole Saturday, Beijing time. OA stands for On Air.

Round #261024 is co-hosted by APRSNETCN and CATHAM 半间猫窝.

One station is on duty each week. Send it a message, it answers with an ACK, and you are on that day's roster. The duty callsign changes every week.

No sign-up, and nothing to be present for.

### 📡 When, and who is on duty

- Round #261024, called 半间猫窝 (Half a Cat Bed)
- Saturday, 24 October 2026, 00:00–23:59 Beijing time (UTC+8)
- In UTC that is 16:00 on 23 October to 15:59 on 24 October
- The duty callsign this week is **BH6RIZ-6**, and zelin is at the key

### 📮 How to join

Address the message to **BH6RIZ-6**.

Send **CQ CNNET BG7XXX OL62** with your own call and your own grid. When the duty station answers with an ACK, send **U CNNET**.

You can also send **CNNET BG7XXX OL62** and skip the CQ step.

A grid of 4 or 6 characters both work, for example OL62 or OL62AA. If a packet arrives without a grid, the duty station answers with a hint; send it once more with the grid in.

Anything you want to pass on to the duty station goes after the grid. That sentence shows up next to your callsign on the roster.

Packets over the network and packets over RF both count, RF first. An RF packet records the digipeaters it went through.

You need a valid callsign and licence, and please follow your local regulations.

### 📋 What shows up

The duty station answers every check-in with an ACK.

Your callsign then appears on the activity page roster, with your grid and the time it arrived.

The roster image and the grid image can be downloaded the same day.

### 🙋 About this round

No scoring, no leaderboard, and no commercial use.

The flow keeps changing; the activity page always carries the current one.

If you miss this one, there is another round next Saturday.

In APRSLocus, open the Messages page and set the recipient to the duty callsign.

The roster for the day is on the activity page. **[Open the activity page](https://oa.aprsnet.cn)**

---

## 💌 A letter to APRSLocus users

### 💌 From BG5ESN

> FMO began as something I simply wanted very much to build myself.
>
> Back then a lot of things had no rules, and there was no "after-sales service", no "server responsibility", no "certificate management". When something went wrong people came to me, and if I could fix it, I fixed it. When someone wanted to tinker, I was glad to dig in with them. Many of the features and many of the ideas grew out of that kind of conversation, a little at a time.
>
> I have always treasured that feeling.
>
> But as the devices multiplied, the servers multiplied and more and more people joined in, I came to see that a project cannot be held up forever by one person's enthusiasm and improvised judgement.
>
> Some things, once there are no boundaries, end up as something that no matter who did it, where it happened, or whether it was ever within my control, in the end I am the one who has to explain it, deal with it, and even answer for it.
>
> That is not a state one person can carry for long.
>
> BG5ESN

As a software developer myself, I feel exactly the same way.

APRSLocus had been in my head for a year. How good it would be to have a proper APRS client of our own, with plenty of room to extend it, lots of features, and fewer rough edges. In the summer holiday of my second year of high school I finally started building it, a practical cross-platform network APRS client.

At first I did not want to support real radios at all. But as it grew I figured that once the work was under way, I might as well add more, and the features piled up one after another. Version 2.0 finally brought in real-radio support, TNCs and the other links, and it became a client with several links at once. That went far beyond what I had planned.

APRSLocus getting this far has depended on your support and trust, and that is what kept the project growing. I like that feeling, the happiness of sharing it with everyone. The features were filled out the same way. The changelog now runs to thousands of lines. I never expected it to last this long, with this many users and this many features.

As the users grew in number, one question came with them. Will this get out of control? I am not sure.

APRS is a free environment. Anyone can send any message, over radio, over the network, across borders. It relies entirely on personal conduct, and that is not enough. The amateur radio scene here is not what I would call clean. At the very least it is a bit of a mess. APRS data is public too, unencrypted, laid out in the open. The data question has to be considered as well.

Back in 2.0 I brought in a new terms of use, to set out how users behave and to ban users, devices and so on. I did it just in case, for the day I might have to consider shutting the service down.

> Some things, once there are no boundaries, end up as something that no matter who did it, where it happened, or whether it was ever within my control, in the end I am the one who has to explain it, deal with it, and even answer for it.

I am glad to have new users join in, sharing and tinkering together. What I do not want is a few people upsetting the order of the whole network. As a software developer, keeping the community in order is a duty I owe it.

I want APRSLocus to be a long-lived project. It should not stop at any one moment. I want it to keep improving and growing with time, to make more interesting things, and to give more back to the APRS ecosystem.

I am in my third year of high school now. I cannot say the project has not affected me. It has become part of my life. Every day I look at who came online and how many users there are; that is what I follow daily. I think it is time I gave myself some room to relax. I am really tired, and I would like more space to breathe.

So the time and service I can offer are limited. I am the developer of the project, one person, and it is hard to meet everyone's needs, but I want to help as far as I can. The project is open source. Anyone can download it, change it, build it, or send a PR and contribute. I also do not want my stepping away to leave the project stalled or stuck.

I want to stop and rest a while.

Thank you for your support and understanding.

73!

**APRSLocus BG7LZQ**

2026.10.19

### 🎵 A song with the letter: 灰色轨迹 (Grey Traces)

@video https://player.bilibili.com/player.html?isOutside=true&aid=829419761&bvid=BV1Ru4y1179h&cid=1227059812&p=1

### 🚩 Report a violation

If you find a violating callsign or violating content, send it in with this form and help the team keep the network in order.

The form is anonymous.

[APRSLocus violation report form](https://ccncqe00x1e4.feishu.cn/share/base/form/shrcn3W4dM6sf47QOfMuYT2kb6b)

---

## 🙏 An apology

During today's maintenance, users in some regions hit login errors, and a batch of callsigns was temporarily banned so the app would not open.

Both are cleared now. If you are stuck on the block page, tap "Check again" and you are back in. Otherwise the app picks it up the next time you start it. No reinstall needed.

The fault was ours. Sorry for the trouble.

73!

---

## 🔔 What is new: 2.2.8

- The online check no longer looks only at the selected channel: when a mirror has no digest, the official repository is asked, so it no longer always fails.
- Release notes now list the SHA-256 of every package, so mirror channels can be checked too.
- On a digest mismatch the row shows the first characters of both digests.
- When the package cannot be read, the row says so instead of blaming the signature.
- The result goes into the log, so you can see which step failed.

---

## 🆔 TOCALL in the official device library

APRSLocus answers to the tocall **APALOC**, now listed in the official TOCALL device library (aprs-deviceid).

The vendor field reads Darion, BG7LZQ, the model APRSLocus, the class software.

Look up APALOC in the official TOCALL table and you will find it.

---

## ✅ The Qingling channel is back

The 2.2.0 build published on the Qingling (清零) channel by mistake has been taken down, and the channel works normally again.

Checking for updates now returns the latest stable version, 2.2.8. If you installed 2.2.0, uninstall it first, then install 2.2.8.

**[Download 2.2.8](https://github.com/dariondong/APRSLocus/releases/download/v2.2.8/APRSLocus_2.2.8.apk)**

---

## 🥚 A small easter egg in 2.1.0: tap, and the planet turns around

The egg is on the **About** page — the spot you most likely pass every day.

That slowly turning star on the cover is not a picture. **Give it a light tap**: it shudders, turns around, and drops you into a page of story. There is a planet turning there too, a number that keeps climbing, people who keep watch on the airwaves — and the people who built this thing alongside them.

There is sound on that page; turn your speakers up. No long press, no five-second wait — one tap and the story arrives. Changed your mind? One more tap turns the cover back, and the story stays closed.

The rest is yours to see.

---

## 📮 We would like to hear from you

APRSLocus has walked a while with 620+ users now. Where it goes next is partly your call: what feels awkward, what is missing, what we should fix first.

**[Take the survey](https://ccncqe00x1e4.feishu.cn/share/base/form/shrcnWcCKNxzSMvlGP54DCrnAZg)**

## 💬 Official QQ group 925025834

Questions, ideas, or just a "copy that": you are welcome to drop in.

**[Join 925025834](https://qun.qq.com/universal-share/share?ac=1&authKey=tqe%2BI6lZzakmEoIBwnSVV9%2BT8Zg36F4%2FejuSGAfEIYiDhj5sGyQUOx%2B3YCU68G05&busi_data=eyJncm91cENvZGUiOiI5MjUwMjU4MzQiLCJ0b2tlbiI6ImxiMTMrTm55MEoxU1o2aFV1V1hLUDRKQkZBR21nTEdNemJFOUM0aE1jOWJLU2lNZUtZaGpOa1dicnlYSk15V0YiLCJ1aW4iOiIzNDIxMDE2MTUwIn0%3D&data=nW_8Q1gX2ft-4C0n9p83Ukel3sHzCwlFOSMnOU0HZ8sCtWkwY3hmqlwVFAZm5ipk2W3hIDPxc6Rl0HoW-nMf8Q&svctype=4&tempid=h5_group_info)**

---

## 🎵 A song for you: 启航的歌 (Set Sail)

@video https://player.bilibili.com/player.html?aid=1304817854&bvid=BV15M4m1k7YN&cid=1556315737&page=1

---

> The planet is still turning, the number is still climbing.
> Thank you, everyone still listening.

**The APRSLocus team**
October 2026
