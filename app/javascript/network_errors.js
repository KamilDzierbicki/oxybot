// A form that could not reach the server must say so, instead of silently doing nothing
document.addEventListener("turbo:fetch-request-error", () => {
  const main = document.querySelector("main")
  if (!main || main.querySelector(".flash--network")) return
  const flash = document.createElement("div")
  flash.className = "flash flash--alert flash--network"
  flash.setAttribute("role", "alert")
  flash.textContent = "Could not reach OxyBot, so nothing was saved. Check your connection and try again."
  main.prepend(flash)
})
