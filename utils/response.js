function ok(data, meta = null) {
  const response = { ok: true, data };
  if (meta) {
    response.meta = meta;
  }
  return response;
}

function fail(res, message, code = 400) {
  return res.status(code).json({
    ok: false,
    error: message
  });
}

module.exports = { ok, fail };
