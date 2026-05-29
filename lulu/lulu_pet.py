import random
import sys
import tkinter as tk
from pathlib import Path
from tkinter import messagebox


APP_DIR = Path(__file__).resolve().parent
ASSET_DIR = APP_DIR / "assets" / "states"
TRANSPARENT = "#ff00ff"


STATE_ALIASES = {
    "idle": "idle",
    "wave": "waving",
    "jump": "jumping",
    "work": "running",
    "review": "review",
    "failed": "failed",
    "waiting": "waiting",
    "run_right": "running-right",
    "run_left": "running-left",
}


CHAT_REPLIES = [
    ("你好", "你好呀，我是 lulu。"),
    ("hello", "Hello! lulu 在这里。"),
    ("累", "那先休息一下，我陪你慢慢来。"),
    ("难", "没关系，我们把它拆小一点。"),
    ("开心", "嘿嘿，lulu 也开心。"),
    ("谢谢", "不用谢，lulu 很乐意陪着你。"),
    ("工作", "收到，我进入认真模式。"),
    ("review", "我来帮你认真看看。"),
]


class LuluPet:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("lulu desktop pet")
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.root.configure(bg=TRANSPARENT)

        try:
            self.root.wm_attributes("-transparentcolor", TRANSPARENT)
        except tk.TclError:
            pass

        self.window_w = 260
        self.window_h = 330
        self.pet_w = 192
        self.pet_h = 208
        self.frame_index = 0
        self.state = "idle"
        self.last_direction = 0
        self.drag_origin = None
        self.drag_window = None
        self.drag_last_x = None
        self.chat_window = None

        self.frames = self.load_frames()

        self.canvas = tk.Canvas(
            self.root,
            width=self.window_w,
            height=self.window_h,
            bg=TRANSPARENT,
            highlightthickness=0,
            bd=0,
        )
        self.canvas.pack()

        self.bubble = self.canvas.create_rectangle(
            18, 18, self.window_w - 18, 82, fill="#fff7d6", outline="#f3a23b", width=2
        )
        self.bubble_text = self.canvas.create_text(
            self.window_w // 2,
            50,
            text="嗨，我是 lulu",
            fill="#4d2a00",
            font=("Microsoft YaHei UI", 10, "bold"),
            width=self.window_w - 52,
        )
        self.pet_image = self.canvas.create_image(
            self.window_w // 2,
            106,
            image=self.frames[self.state][0],
            anchor="n",
        )

        self.menu = self.build_menu()
        self.bind_events()
        self.place_initially()
        self.animate()
        self.root.after(6500, self.idle_chatter)

    def load_frames(self):
        if not ASSET_DIR.exists():
            messagebox.showerror("lulu", f"Missing assets folder:\n{ASSET_DIR}")
            sys.exit(1)

        frames = {}
        for state_dir in sorted(ASSET_DIR.iterdir()):
            if not state_dir.is_dir():
                continue
            images = []
            for image_path in sorted(state_dir.glob("*.png")):
                images.append(tk.PhotoImage(file=str(image_path)))
            if images:
                frames[state_dir.name] = images

        missing = sorted(set(STATE_ALIASES.values()) - set(frames))
        if missing:
            messagebox.showerror("lulu", "Missing animation states:\n" + ", ".join(missing))
            sys.exit(1)
        return frames

    def build_menu(self):
        menu = tk.Menu(self.root, tearoff=False)
        menu.add_command(label="待机", command=lambda: self.say_and_state("我在这里。", "idle"))
        menu.add_command(label="挥手", command=lambda: self.say_and_state("嗨嗨。", "wave"))
        menu.add_command(label="跳一下", command=lambda: self.say_and_state("跳起来。", "jump"))
        menu.add_command(label="工作中", command=lambda: self.say_and_state("认真处理事情中。", "work"))
        menu.add_command(label="审阅中", command=lambda: self.say_and_state("让我仔细看看。", "review"))
        menu.add_command(label="等待", command=lambda: self.say_and_state("我等你的下一步。", "waiting"))
        menu.add_separator()
        menu.add_command(label="随机动作", command=self.random_action)
        menu.add_command(label="退出 lulu", command=self.root.destroy)
        return menu

    def bind_events(self):
        self.canvas.bind("<ButtonPress-1>", self.start_drag)
        self.canvas.bind("<B1-Motion>", self.drag)
        self.canvas.bind("<ButtonRelease-1>", self.end_drag)
        self.canvas.bind("<Double-Button-1>", lambda _event: self.random_action())
        self.canvas.bind("<Button-3>", self.show_menu)

    def place_initially(self):
        self.root.update_idletasks()
        screen_w = self.root.winfo_screenwidth()
        screen_h = self.root.winfo_screenheight()
        x = max(20, screen_w - self.window_w - 80)
        y = max(20, screen_h - self.window_h - 80)
        self.root.geometry(f"{self.window_w}x{self.window_h}+{x}+{y}")

    def set_state(self, alias):
        next_state = STATE_ALIASES.get(alias, alias)
        if self.state != next_state:
            self.state = next_state
            self.frame_index = 0

    def say(self, text):
        self.canvas.itemconfigure(self.bubble_text, text=text)
        self.canvas.itemconfigure(self.bubble, state="normal")
        self.canvas.itemconfigure(self.bubble_text, state="normal")
        self.root.after(5000, self.hide_bubble)

    def say_and_state(self, text, alias):
        self.set_state(alias)
        self.say(text)

    def hide_bubble(self):
        self.canvas.itemconfigure(self.bubble, state="hidden")
        self.canvas.itemconfigure(self.bubble_text, state="hidden")

    def show_menu(self, event):
        self.menu.tk_popup(event.x_root, event.y_root)

    def start_drag(self, event):
        self.drag_origin = (event.x_root, event.y_root)
        self.drag_window = (self.root.winfo_x(), self.root.winfo_y())
        self.drag_last_x = event.x_root
        self.last_direction = 0
        self.canvas.itemconfigure(self.bubble, state="hidden")
        self.canvas.itemconfigure(self.bubble_text, state="hidden")

    def drag(self, event):
        if self.drag_origin is None or self.drag_window is None:
            return

        dx = event.x_root - self.drag_origin[0]
        dy = event.y_root - self.drag_origin[1]
        self.root.geometry(f"+{self.drag_window[0] + dx}+{self.drag_window[1] + dy}")

        move_dx = event.x_root - (self.drag_last_x or event.x_root)
        direction = 0
        if move_dx >= 2:
            direction = 1
        elif move_dx <= -2:
            direction = -1

        if direction and direction != self.last_direction:
            self.set_state("run_right" if direction > 0 else "run_left")
            self.last_direction = direction
        self.drag_last_x = event.x_root

    def end_drag(self, _event):
        self.drag_origin = None
        self.drag_window = None
        self.drag_last_x = None
        self.last_direction = 0
        self.set_state("idle")
        self.say(random.choice(["放好啦。", "这里不错。", "我站稳了。"]))

    def random_action(self):
        action = random.choice(
            [
                ("wave", "嗨嗨。"),
                ("jump", "跳一下。"),
                ("waiting", "坐一会儿。"),
                ("review", "点点头。"),
                ("failed", "变小只。"),
                ("work", "认真模式。"),
            ]
        )
        self.say_and_state(action[1], action[0])

    def animate(self):
        state_frames = self.frames[self.state]
        frame = state_frames[self.frame_index % len(state_frames)]
        self.canvas.itemconfigure(self.pet_image, image=frame)
        self.frame_index += 1

        if self.state not in {"idle", "running-right", "running-left", "running"}:
            if self.frame_index >= len(state_frames) * 2:
                self.set_state("idle")

        self.root.after(145, self.animate)

    def idle_chatter(self):
        if self.state == "idle" and random.random() < 0.5:
            self.say(random.choice(["我陪着你。", "要开始做点什么吗？", "lulu 待命中。"]))
        self.root.after(random.randint(9000, 16000), self.idle_chatter)

    def open_chat(self):
        if self.chat_window and self.chat_window.winfo_exists():
            self.chat_window.lift()
            return

        self.chat_window = tk.Toplevel(self.root)
        self.chat_window.title("和 lulu 聊天")
        self.chat_window.attributes("-topmost", True)
        self.chat_window.geometry(
            f"340x170+{self.root.winfo_x() - 360}+{self.root.winfo_y() + 80}"
        )
        self.chat_window.resizable(False, False)

        label = tk.Label(
            self.chat_window,
            text="和 lulu 说句话：",
            font=("Microsoft YaHei UI", 10),
            anchor="w",
        )
        label.pack(fill="x", padx=12, pady=(12, 4))

        entry = tk.Entry(self.chat_window, font=("Microsoft YaHei UI", 10))
        entry.pack(fill="x", padx=12)
        entry.focus_set()

        reply = tk.Label(
            self.chat_window,
            text="lulu 会用本地规则回复，不会调用任何 API。",
            font=("Microsoft YaHei UI", 9),
            fg="#6a4b14",
            wraplength=310,
            justify="left",
        )
        reply.pack(fill="x", padx=12, pady=10)

        def send():
            text = entry.get().strip()
            if not text:
                return
            answer = self.reply_to(text)
            reply.configure(text=answer)
            self.say(answer)
            entry.delete(0, "end")

        send_button = tk.Button(self.chat_window, text="发送", command=send)
        send_button.pack(pady=(0, 10))
        entry.bind("<Return>", lambda _event: send())

    def reply_to(self, text):
        lowered = text.lower()
        for key, answer in CHAT_REPLIES:
            if key.lower() in lowered:
                if key in {"工作", "work"}:
                    self.set_state("work")
                elif key == "review":
                    self.set_state("review")
                else:
                    self.set_state(random.choice(["wave", "idle", "waiting"]))
                return answer

        self.set_state(random.choice(["waiting", "review", "wave"]))
        return random.choice(
            [
                "我听到啦。",
                "这个我记在心里。",
                "嗯嗯，我们慢慢来。",
                "lulu 明白一点点了。",
            ]
        )

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    LuluPet().run()
