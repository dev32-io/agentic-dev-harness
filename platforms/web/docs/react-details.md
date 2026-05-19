# React -- Details & Examples

This file expands `platforms/web/rules/react.md`.

## Derived state in render -- the canonical example

```tsx
// WRONG -- mirror prop into state via effect.
function Filtered({ items, query }: Props) {
    const [filtered, setFiltered] = useState<Item[]>(items);
    useEffect(() => {
        setFiltered(items.filter(i => i.name.includes(query)));
    }, [items, query]);
    return <List items={filtered} />;
}
```

Problems: extra render every time inputs change; UI shows stale
data for one render; the effect can run with the wrong deps if a
reviewer "fixes" the dependency array.

```tsx
// RIGHT -- compute in render. No state, no effect.
function Filtered({ items, query }: Props) {
    const filtered = items.filter(i => i.name.includes(query));
    return <List items={filtered} />;
}

// Add useMemo only if profiling shows the filter is expensive
// AND `items` is reference-stable across renders:
function Filtered({ items, query }: Props) {
    const filtered = useMemo(
        () => items.filter(i => i.name.includes(query)),
        [items, query],
    );
    return <List items={filtered} />;
}
```

`useMemo` memoizes the COMPUTATION; it does not "save" a value
the way `useState` does. If `items` is a fresh array every
render, `useMemo` still re-runs the filter.

## When `useEffect` IS correct

External systems only:

```tsx
useEffect(() => {
    const socket = new WebSocket(url);
    socket.onmessage = onMessage;
    return () => socket.close();
}, [url, onMessage]);
```

Network, DOM, timers, subscriptions, focus management on real
DOM elements -- those are effects. Everything that is a pure
function of props + state is not.

## Custom hooks compose cleanly

```tsx
function useDebouncedValue<T>(value: T, ms: number): T {
    const [debounced, setDebounced] = useState(value);
    useEffect(() => {
        const id = setTimeout(() => setDebounced(value), ms);
        return () => clearTimeout(id);
    }, [value, ms]);
    return debounced;
}

function SearchBox() {
    const [query, setQuery] = useState("");
    const debouncedQuery = useDebouncedValue(query, 300);
    const results = useSearch(debouncedQuery);
    return (
        <>
            <input value={query} onChange={e => setQuery(e.target.value)} />
            <Results items={results} />
        </>
    );
}
```

The class-component equivalent is roughly twice the lines and
cannot be composed with another stateful behavior without
inheritance gymnastics.

## Stable keys -- the bug index-keys cause

```tsx
// WRONG -- reorderable list with index-as-key.
{items.map((item, i) => <Row key={i} item={item} />)}

// Reorder items[1] and items[2]. React reuses Row #1 for the
// new item at position 1 and Row #2 for the new item at
// position 2. If Row owns local state (an editing flag, a
// focused field), that state stays with the position, not with
// the item. The user sees their edit flow to the wrong row.

// RIGHT.
{items.map(item => <Row key={item.id} item={item} />)}
```

## Mutating state -- spot the bug

```tsx
// WRONG -- mutates the existing array.
const onAdd = (next: Item) => {
    items.push(next);
    setItems(items);
};

// React sees the same reference and skips the re-render.

// RIGHT.
const onAdd = (next: Item) => {
    setItems(prev => [...prev, next]);
};
```

For nested objects, prefer Immer (`produce`) or structural
spread; never mutate in place.

## Server Components vs Client Components

In an RSC framework (Next.js App Router):

```tsx
// app/products/page.tsx -- Server Component by default.
async function ProductsPage() {
    const products = await db.products.findMany();
    return <ProductList products={products} />;
}

// app/products/AddToCartButton.tsx -- needs interactivity.
"use client";
export function AddToCartButton({ productId }: { productId: string }) {
    const [pending, setPending] = useState(false);
    return <button onClick={...} disabled={pending}>Add</button>;
}
```

Rules of thumb:

- Data fetching: prefer Server Components. No client-side
  loading state for data the server already had.
- Interactivity (event handlers, local state, hooks beyond
  `use`): Client Component.
- Mark the boundary explicitly. Do not turn a whole subtree
  client-side because one leaf needs `onClick`.

## Setter-during-render -- the infinite loop

```tsx
// WRONG -- unconditional setter from render body.
function Component({ value }: Props) {
    setLocal(value);                       // re-renders forever
    return <div>{local}</div>;
}

// RIGHT -- if you really need to update state from a prop
// change without an effect, useReducer with a derived dispatch
// or computeAndStore in an event handler.
```

Most "I need to set state from props" cases were derived state
in disguise. Compute in render and the problem disappears.

## When to disable an exhaustive-deps warning

Almost never. If you must:

```tsx
// eslint-disable-next-line react-hooks/exhaustive-deps -- onMessage
// changes every render but its identity is intentional; we
// re-subscribe is exactly the desired behavior.
useEffect(() => { /* ... */ }, [url]);
```

Reviewer: that comment is the contract. Without it, the disable
is rejected.
