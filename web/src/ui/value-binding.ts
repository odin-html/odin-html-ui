/* Reactive binding for hidden inputs, shared by selectbox, datepicker and
 * timepicker -- three private copies under the delegation model, one module
 * now.
 *
 * Setting input.value programmatically does not fire an `input` event; that
 * has been browser behaviour forever. Components whose display mirrors a
 * hidden input need to hear those writes, so the value setter is overridden
 * per instance to dispatch one. The property lands on the element itself and
 * dies with it -- nothing here to tear down. */

const bound = new WeakSet<HTMLInputElement>()

export function enableValueBinding(input: HTMLInputElement): void {
  if (bound.has(input)) return
  bound.add(input)

  const desc = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value")
  if (!desc?.get || !desc.set) return
  const get = desc.get as (this: HTMLInputElement) => string
  const set = desc.set as (this: HTMLInputElement, v: string) => void

  Object.defineProperty(input, "value", {
    get,
    set(this: HTMLInputElement, v: string) {
      const old = get.call(this)
      set.call(this, v)
      if (old !== v) {
        this.dispatchEvent(new Event("input", { bubbles: true }))
      }
    },
    configurable: true,
  })
}
