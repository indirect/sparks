# Sparks
### a tiny campfire library

So it turns out that Tinder requires nine gems nowadays, including EventMachine and the Twitter streaming API client gem, and that is too much for me. So, (strongly inspired by Aaron Patterson's A Bot), I wrote this extremely tiny Campfire client API. Share and enjoy.

### Known Issues

The `watch` method tends to succumb to network issues after a few hours, and is probably not suitable for building a long-running bot that listens to a room. This library is fantastic for anything that says things into a room based on other ruby code, though.
