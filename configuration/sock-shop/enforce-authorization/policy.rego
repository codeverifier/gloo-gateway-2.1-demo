package test

# Default is deny all
default allow = false

# Look for the auth header
jwt = j {
  auth_header := input.check_request.attributes.request.http.headers["x-authorization"]
  [b, j] := split(auth_header, " ")
  "bearer" == lower(b)
}

# Decode JWT token
token_payload := payload {
	[_, payload, _] := io.jwt.decode(jwt)
}

# Policy to access /
allow {
    startswith(input.http_request.path, "/")
    token_payload["org"] == "solo.io"
}