import { useState, useEffect } from 'react'

const API_URL = window.__ENV__?.API_URL || 'http://localhost:8080'

export default function App() {
  const [products, setProducts] = useState([])
  const [health, setHealth] = useState({})
  const [error, setError] = useState(null)

  useEffect(() => {
    fetch(`${API_URL}/health`)
      .then(r => r.json())
      .then(data => setHealth(data))
      .catch(() => setHealth({ status: 'unreachable' }))

    fetch(`${API_URL}/api/products`)
      .then(r => r.json())
      .then(data => setProducts(data))
      .catch(err => setError(err.message))
  }, [])

  return (
    <div style={{ fontFamily: 'system-ui', maxWidth: 960, margin: '0 auto', padding: 20 }}>
      <h1>CloudShop</h1>
      <p>API Gateway: <strong>{health.status || 'loading...'}</strong></p>

      <h2>Products</h2>
      {error && <p style={{ color: 'red' }}>Error: {error}</p>}
      {products.length === 0 && !error && <p>No products found.</p>}
      <ul>
        {products.map(p => (
          <li key={p.id}>{p.name} - ${p.price}</li>
        ))}
      </ul>
    </div>
  )
}
