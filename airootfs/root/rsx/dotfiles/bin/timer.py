import tkinter as tk
from math import pi, sin, cos

# Default value
DEFAULT_MINUTES = 25

# Time in seconds
minutes = int(input("Enter the number of minutes (default is 25): ") or DEFAULT_MINUTES)
seconds = minutes * 60

# Create the root window
root = tk.Tk()
root.title("Circular Progress Bar")
root.geometry("200x200")
root.configure(bg='#2e2e2e')
root.overrideredirect(True)  # Remove window decorations

# Create a canvas for the circular progress bar
canvas = tk.Canvas(root, width=200, height=200, bg='#2e2e2e', highlightthickness=0)
canvas.pack()

# Make the window circular
def make_circle_window():
    root.update_idletasks()
    x0, y0, x1, y1 = canvas.bbox("all")
    x0, y0, x1, y1 = x0 - 10, y0 - 10, x1 + 10, y1 + 10
    width, height = x1 - x0, y1 - y0

    root.geometry(f"{width}x{height}+{root.winfo_x()}+{root.winfo_y()}")
    radius = width // 2

    # Create a circular shape
    mask = tk.PhotoImage(width=width, height=height)
    mask.put(("black",), to=(0, 0, width, height))
    mask.put(("white",), to=(10, 10, width-10, height-10))
    root.wm_attributes("-alpha", 0.0)
    root.geometry(f"{width}x{height}+{root.winfo_x()}+{root.winfo_y()}")

    root.update_idletasks()
    root.wm_attributes("-alpha", 1.0)
    root.wm_attributes("-transparentcolor", "#2e2e2e")

# Function to format time in MM:SS
def format_time(seconds):
    mins = seconds // 60
    secs = seconds % 60
    return f"{mins:02}:{secs:02}"

# Function to draw the circular progress bar
def draw_circle_progress(progress, remaining_time):
    canvas.delete("all")
    canvas.create_oval(10, 10, 190, 190, outline='#404040', width=15)
    extent = progress * 360
    canvas.create_arc(10, 10, 190, 190, start=-90, extent=extent, outline='#00ccff', width=15, style=tk.ARC)
    canvas.create_text(100, 100, text=remaining_time, fill='white', font=('Helvetica', 20, 'bold'))

# Function to update the progress
def update_progress():
    global seconds
    if seconds > 0:
        progress = (minutes * 60 - seconds) / (minutes * 60)
        remaining_time = format_time(seconds)
        draw_circle_progress(progress, remaining_time)
        seconds -= 1
        root.after(1000, update_progress)
    else:
        draw_circle_progress(1, "00:00")  # Fill the circle completely and show "00:00" when time is up

# Call the make_circle_window function after the root window is initialized
root.after(0, make_circle_window)

# Start the timer
root.after(1000, update_progress)
root.mainloop()
