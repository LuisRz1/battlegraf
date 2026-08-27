"""Cliente Supabase administrativo (service role) para el router Panel.

Usa la URL y la service role key del entorno. Todas las operaciones
del panel se hacen desde el servidor para no depender del RLS del lado
del cliente.
"""

from functools import lru_cache

from src.infrastructure.config import get_settings


@lru_cache(maxsize=1)
def supabase_admin():
    """Devuelve un cliente Supabase con la service role key."""
    settings = get_settings()
    url = settings.supabase_url
    # Preferir la key en formato nuevo (sb_secret_...); si no, la service role JWT
    key = settings.supabase_secret_key or settings.supabase_service_role_key
    if not url or not key:
        raise RuntimeError("Supabase admin no configurado (url/service key)")
    try:
        from supabase import create_client, Client

        client: Client = create_client(url, key)
        return client
    except ImportError:  # pragma: no cover - fallback con httpx
        return _SupabaseHttpAdmin(url, key)


class _SupabaseHttpAdmin:
    """Cliente REST mínimo si `supabase` no está instalado."""

    def __init__(self, url: str, key: str):
        self.url = url.rstrip("/")
        self.headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        }
        self._session = None

    def _http(self):
        if self._session is None:
            import httpx

            self._session = httpx.Client(
                timeout=30,
                headers=self.headers,
                verify=False,  # dev local (MITM Kaspersky); Railway usa TLS real
            )
        return self._session

    def table(self, name: str):
        return _TableRef(self, name)

    def rpc(self, fn: str, params: dict):
        import httpx

        resp = self._http().post(f"{self.url}/rest/v1/rpc/{fn}", json=params)
        if resp.status_code >= 400:
            raise RuntimeError(resp.text[:200])
        return _Resp(resp.json())

    def close(self):
        if self._session is not None:
            self._session.close()


class _Resp:
    def __init__(self, data):
        self.data = data

    def execute(self):
        """Compatibilidad: la API de supabase-py usa .insert(...).execute()."""
        return self


class _TableRef:
    def __init__(self, client, name: str):
        self._client = client
        self._name = name
        self._filters: list[tuple] = []
        self._order = None
        self._limit_v = None
        self._select_cols = "*"
        self._pending_mutation: tuple[str, dict | None] | None = None

    def select(self, cols: str = "*") -> "_TableRef":
        self._select_cols = cols
        return self

    def eq(self, col: str, val) -> "_TableRef":
        self._filters.append((col, "eq", val))
        return self

    def in_(self, col: str, vals) -> "_TableRef":
        self._filters.append((col, "in", vals))
        return self

    def order(self, col: str, ascending: bool = True) -> "_TableRef":
        self._order = f"{col}.desc" if not ascending else col
        return self

    def limit(self, n: int) -> "_TableRef":
        self._limit_v = n
        return self

    def _url(self) -> str:
        import urllib.parse

        parts = [f"select={urllib.parse.quote(self._select_cols)}"]
        for col, op, val in self._filters:
            if op == "eq":
                parts.append(f"{col}=eq.{urllib.parse.quote(str(val))}")
            elif op == "in":
                parts.append(f"{col}=in.({','.join(str(v) for v in val)})")
        if self._order:
            parts.append(f"order={self._order}")
        if self._limit_v is not None:
            parts.append(f"limit={self._limit_v}")
        return f"{self._client.url}/rest/v1/{self._name}?" + "&".join(parts)

    def execute(self) -> _Resp:
        import httpx

        if self._pending_mutation is not None:
            method, payload = self._pending_mutation
            if method == "PATCH":
                resp = self._client._http().patch(self._url(), json=payload, headers={"Prefer": "return=minimal"})
            else:
                resp = self._client._http().delete(self._url(), headers={"Prefer": "return=minimal"})
            if resp.status_code >= 400:
                raise RuntimeError(resp.text[:200])
            self._pending_mutation = None
            return _Resp(None)
        resp = self._client._http().get(self._url())
        if resp.status_code >= 400:
            raise RuntimeError(resp.text[:200])
        return _Resp(resp.json())

    def insert(self, payload: dict) -> _Resp:
        import httpx

        resp = self._client._http().post(
            self._url().split("?")[0],
            json=payload,
            headers={"Prefer": "return=representation"},
        )
        if resp.status_code >= 400:
            raise RuntimeError(resp.text[:200])
        try:
            return _Resp(resp.json())
        except Exception:  # noqa: BLE001 - cuerpo vacío en algunos casos
            return _Resp([payload])

    def update(self, payload: dict) -> "_TableRef":
        self._pending_mutation = ("PATCH", payload)
        return self

    def delete(self) -> "_TableRef":
        self._pending_mutation = ("DELETE", None)
        return self