#!/usr/bin/env python3
"""Browser Use runner for Pawscript.

Reads a Pawscript skill payload, executes it in a visible browser, and emits
JSONL status events for the Swift app.
"""

import asyncio
import json
import os
import sys
from pathlib import Path


def emit(event_type, message, step_number=None):
    print(
        json.dumps(
            {"type": event_type, "message": message, "stepNumber": step_number},
            ensure_ascii=False,
        ),
        flush=True,
    )


def looks_like_human_handoff(text):
    lowered = text.lower()
    if "pawscript_needs_human" in lowered:
        return True

    handoff_phrases = [
        "404",
        "page not found",
        "not found",
        "empty dom",
        "empty dom tree",
        "stale tutorial url",
        "requires login",
        "requires sign in",
        "sign in required",
        "login required",
        "need to sign in",
        "needs to sign in",
        "must be signed in",
        "must log in",
        "please sign in",
        "please log in",
        "requires authentication",
        "credentials required",
        "need credentials",
        "can't continue without",
        "cannot continue without",
    ]
    return any(phrase in lowered for phrase in handoff_phrases)


def clean_handoff_message(text):
    marker = "PAWSCRIPT_NEEDS_HUMAN:"
    if marker in text:
        return text.split(marker, 1)[1].strip().splitlines()[0][:500]
    return text.strip()[:500] or "The browser workflow needs a human checkpoint before it can continue."


async def wait_for_human_signal(control_dir):
    """Wait for Swift to tell the live browser run to resume or stop."""
    if not control_dir:
        return {"action": "stop", "note": "No Pawscript control directory was provided."}

    control_path = Path(control_dir)
    control_path.mkdir(parents=True, exist_ok=True)
    resume_path = control_path / "resume.json"
    stop_path = control_path / "stop.json"

    while True:
        if stop_path.exists():
            try:
                signal = json.loads(stop_path.read_text(encoding="utf-8"))
                signal["action"] = "stop"
                return signal
            except Exception:
                return {"action": "stop", "note": "Stopped by user."}

        if resume_path.exists():
            try:
                signal = json.loads(resume_path.read_text(encoding="utf-8"))
            except Exception:
                signal = {"note": "User says the blocker is resolved."}
            signal["action"] = "resume"
            try:
                resume_path.unlink()
            except OSError:
                pass
            return {"action": "resume", **signal}

        await asyncio.sleep(0.35)


def build_task(payload):
    package = payload["skill"]
    user_goal = payload.get("userGoal") or "Complete the tutorial workflow."
    skill = package["skill"]
    steps = sorted(package["steps"], key=lambda step: step.get("number", 0))
    prerequisites = package.get("prerequisites") or []
    prerequisite_text = "\n".join(
        f"- {item.get('title')}: {item.get('detail')} ({'blocking' if item.get('isBlocking') else 'heads up'})"
        for item in prerequisites
    ) or "- None recorded. Still check whether the live page requires sign-in, an account, a demo asset, or private credentials."
    step_text = "\n\n".join(
        "\n".join(
            part
            for part in [
                f"{step.get('number')}. {step.get('title')}",
                f"Action: {step.get('action')}",
                f"Target: {step.get('target')}" if step.get("target") else "",
                f"Value: {step.get('value')}" if step.get("value") else "",
                f"Instruction: {step.get('description')}",
                f"Verification: {step.get('verification')}" if step.get("verification") else "",
                f"Gotcha: {step.get('gotchaText')}" if step.get("gotchaText") else "",
            ]
            if part
        )
        for step in steps
    )

    return f"""
You are Browser Use executing a Pawscript skill in a visible browser.

User goal:
{user_goal}

Skill:
{skill.get('title')}

Source:
{package.get('sourceURL')}

Safety rules:
- Complete only browser-based steps.
- Do not log in, purchase, submit private data, change account settings, or perform destructive actions.
- If the page requires sign-in, credentials, an account setup, a private file, private data, or a missing demo asset, stop immediately.
- If a navigate step returns 404, page not found, or an empty DOM after one retry, stop immediately and say the tutorial URL is stale.
- When stopping for the user, include exactly this marker in your final answer: PAWSCRIPT_NEEDS_HUMAN: <what the user should do>.
- Do not repeatedly retry stale URLs. Hand off quickly instead.
- Prefer public pages and demo-safe interactions.
- When done, provide a concise completion summary.

Known prerequisites:
{prerequisite_text}

Steps:
{step_text}
""".strip()


def build_resume_task(payload, handoff_message, resume_note):
    base_task = build_task(payload)
    note = resume_note or "The user completed the human-only checkpoint."
    return f"""
{base_task}

Resume context:
- Browser Use previously paused because: {handoff_message}
- The user has now taken over the visible browser and says: {note}
- Continue from the current visible browser state. Do not reopen stale URLs if the current page is already the right app/editor.
- If login, account setup, or asset upload is still not complete, hand off again quickly with PAWSCRIPT_NEEDS_HUMAN.
""".strip()


async def main():
    if len(sys.argv) != 2:
        emit("error", "Usage: pawscript_browser_agent.py payload.json")
        return 2

    payload_path = sys.argv[1]
    with open(payload_path, "r", encoding="utf-8") as file:
        payload = json.load(file)

    if not os.environ.get("OPENAI_API_KEY"):
        emit("error", "OPENAI_API_KEY is missing.")
        return 2

    try:
        from browser_use import Agent
        try:
            from browser_use import BrowserSession
        except Exception:
            BrowserSession = None
        try:
            from browser_use.llm import ChatOpenAI
        except Exception:
            from langchain_openai import ChatOpenAI
    except Exception as exc:
        emit("error", f"Browser Use imports failed: {exc}")
        return 2

    task = build_task(payload)
    emit("start", "Browser Use is opening a visible browser.")

    llm = ChatOpenAI(model="gpt-4o-mini")
    browser_profile_dir = os.environ.get("PAWSCRIPT_BROWSER_PROFILE_DIR")
    control_dir = os.environ.get("PAWSCRIPT_CONTROL_DIR")

    if BrowserSession is not None:
        browser_kwargs = {
            "headless": False,
            "keep_alive": True,
        }
        if browser_profile_dir:
            Path(browser_profile_dir).mkdir(parents=True, exist_ok=True)
            browser_kwargs["user_data_dir"] = browser_profile_dir
            emit("profile", "Using Pawscript's persistent browser profile.")
        browser_session = BrowserSession(**browser_kwargs)
    else:
        browser_session = None

    handoff_count = 0
    max_handoffs = 5
    while True:
        if browser_session is not None:
            agent = Agent(task=task, llm=llm, browser_session=browser_session)
        else:
            agent = Agent(task=task, llm=llm)

        emit("running", "Executing the Pawscript skill.")
        try:
            result = await agent.run(max_steps=12)
        except Exception as exc:
            message = clean_handoff_message(str(exc))
            if looks_like_human_handoff(str(exc)):
                result_text = f"PAWSCRIPT_NEEDS_HUMAN: {message}"
            else:
                raise
        else:
            result_text = str(result)

        if not looks_like_human_handoff(result_text):
            emit("complete", result_text[-1200:])
            return 0

        handoff_count += 1
        message = clean_handoff_message(result_text)
        emit("needs_human", message)
        print(message, file=sys.stderr, flush=True)

        if handoff_count >= max_handoffs:
            emit("error", "Too many human checkpoints in one Browser Use run.")
            return 3

        signal = await wait_for_human_signal(control_dir)
        if signal.get("action") == "stop":
            emit("stopped", signal.get("note") or "Stopped by user.")
            return 4

        resume_note = signal.get("note") or "User resolved the blocker."
        emit("resumed", resume_note)
        task = build_resume_task(payload, message, resume_note)


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
