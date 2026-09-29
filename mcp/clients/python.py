# Calls the skanqrcode MCP server's `check_url` tool directly from an agent you're building,
# instead of going through Claude Desktop's config UI. Requires the server already built:
# see ../server/README.md.
#
#   pip install mcp
#   SKANQRCODE_API_KEY=lure_test_... python3 python.py "https://example.com/login"

import asyncio
import json
import os
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def check_url(target: str) -> dict:
    params = StdioServerParameters(
        command="node",
        args=["../server/dist/index.js"],
        env={"SKANQRCODE_API_KEY": os.environ.get("SKANQRCODE_API_KEY", "")},
    )
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool("check_url", {"target": target})
            if result.isError:
                raise RuntimeError(f"check_url failed: {result.content}")
            return json.loads(result.content[0].text)


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: python.py <url-or-ip>", file=sys.stderr)
        sys.exit(1)

    target = sys.argv[1]
    verdict = asyncio.run(check_url(target))
    print(verdict)

    if verdict["recommendation"] == "block":
        print(f"Refusing to fetch {target}: {', '.join(verdict['reasons'])}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
