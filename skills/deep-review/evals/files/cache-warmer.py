import time


def warm(keys, client, delay=0.1):
    warmed = []
    for key in keys:
        try:
            client.get(key)
            warmed.append(key)
        except Exception:
            continue
        time.sleep(delay)
    return warmed


def warm_all(client):
    return warm(client.list_keys(), client)
