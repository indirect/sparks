# Sparks
### a tiny campfire library

So it turns out that Tinder requires nine gems nowadays, including EventMachine and the Twitter streaming API client gem. That is too many gems for me. So I wrote this extremely tiny Campfire client API based on Aaron Patterson's A Bot. Share and enjoy.

### Known Issues

The `watch` method tends to succumb to network issues after a few hours, and is probably not suitable for building a long-running bot that listens to a room. This library is fantastic for anything that says things into a room based on other ruby code, though.

### Contributors

Ben Bleything (@bleything) for the :ca_file option
James Cox (@imajes) for the #play and #tweet methods

#### Thanks to

Aaron Patterson (@tenderlove) for the original A Bot code