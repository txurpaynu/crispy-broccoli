const button = document.getElementById("share");
const status = document.getElementById("status");

button.addEventListener("click", async () => {
  button.disabled = true;
  status.textContent = "Sending…";
  try {
    const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
    if (!tab || !tab.url) throw new Error("Safari didn't provide the current page.");
    await browser.runtime.sendNativeMessage("com.shimeji.companion", {
      type: "sharePage",
      url: tab.url
    });
    status.textContent = "Done! Vexley will have something to say.";
  } catch (error) {
    status.textContent = error.message || "Couldn't reach Vexley. Open Shimeji and enable notifications first.";
    button.disabled = false;
  }
});
