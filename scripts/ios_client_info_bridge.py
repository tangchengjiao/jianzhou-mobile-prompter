"""Local iLoader compatibility bridge used successfully on 2026-10-26.

Client metadata reference: SideInstaller/ios-app/PairingTargets.swift,
SideStoreAnisetteHandoff. See docs/07-iPhone自用安装.md for the verified flow.
"""
import asyncio
from aiohttp import ClientSession, ClientTimeout, WSMsgType, web

# Public client metadata used by current SideStore/SideInstaller. Apple account
# requests still go directly from iLoader to Apple; this bridge has no login API.
UPSTREAM = "https://new.ani.sidestore.io"
CLIENT_INFO = {
    "client_info": "<MacBookPro18,3> <macOS;26.6;25F84> <com.apple.AuthKit/1 (com.apple.akd/1.0)>",
    "user_agent": "AuthKit/1 (Macintosh; OS X 26.6) (com.apple.akd/1.0)",
}


async def client_info(request):
    return web.json_response(CLIENT_INFO)


async def headers(request):
    async with request.app["client"].post(
        UPSTREAM + "/v3/get_headers",
        data=await request.read(),
        headers={"Content-Type": "application/json"},
    ) as response:
        return web.Response(body=await response.read(), status=response.status,
                            content_type="application/json")


async def relay(source, target):
    async for message in source:
        if message.type == WSMsgType.TEXT:
            await target.send_str(message.data)
        elif message.type == WSMsgType.BINARY:
            await target.send_bytes(message.data)
        else:
            break


async def provisioning(request):
    remote_url = UPSTREAM.replace("https://", "wss://") + "/v3/provisioning_session"
    async with request.app["client"].ws_connect(remote_url) as remote:
        local = web.WebSocketResponse()
        await local.prepare(request)
        tasks = [asyncio.create_task(relay(local, remote)),
                 asyncio.create_task(relay(remote, local))]
        _, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for task in pending:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        await local.close()
        return local


async def startup(app):
    app["client"] = ClientSession(timeout=ClientTimeout(total=60), trust_env=True)


async def cleanup(app):
    await app["client"].close()


app = web.Application()
app.router.add_get("/v3/client_info", client_info)
app.router.add_post("/v3/get_headers", headers)
app.router.add_get("/v3/provisioning_session", provisioning)
app.on_startup.append(startup)
app.on_cleanup.append(cleanup)
if __name__ == "__main__":
    web.run_app(app, host="127.0.0.1", port=48219, access_log=None, print=None)
