describe("coursier", function()
  local coursier = require("scala-utils.coursier")

  it("can complete given partial org", function()
    local completions = coursier.complete("org.scalamet")
    local expected = { "org.scalameta" }
    assert.are.same(completions, expected)
  end)

  it("can complete given org and partival artifact", function()
    local completions = coursier.complete("org.scalameta:mdoc-inter")
    local expected = { "mdoc-interfaces" }
    assert.are.same(completions, expected)
  end)

  it("can complete given org and artifact and partial version", function()
    local completions = coursier.complete("org.scalameta:mdoc_2.13:1")
    local expected = { "1.3.2", "1.3.4", "1.3.5", "1.3.6", "1.4.0-RC2", "1.4.0-RC3" }
    assert.are.same(completions, expected)
  end)
end)
