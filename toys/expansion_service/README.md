# Overview

A centralized service provided to expansion player.

# Key Points

1. Any one can create scene.
2. Show scenes list.
3. Service receive player msg, cache them into queue.
4. Service must advance all registed scene.
5. The service converts player messages into transactions, and sends them up the chain.
6. As a demo, the service does not persist messages, although this is very important.
7. How to motivate people to deploy services?
