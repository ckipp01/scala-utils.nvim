local eq = assert.are.same

describe("coursier", function()
  local coursier = require("scala-utils.coursier")

  it("can complete given partial org", function()
    local completions = coursier.complete("org.scala-sb")
    local expected = { "org.scala-sbt" }
    eq(completions, expected)
  end)

  it("can complete given org and partival artifact", function()
    local completions = coursier.complete("org.scalameta:mdoc-inter")
    local expected = { "mdoc-interfaces" }
    eq(completions, expected)
  end)

  it("can complete given org and artifact and partial version", function()
    local completions = coursier.complete("org.scalameta:mdoc_2.13:1")
    local expected = { "1.3.2", "1.3.4", "1.3.5", "1.3.6", "1.4.0-RC2", "1.4.0-RC3" }
    eq(completions, expected)
  end)

  --local feed = function(text, feed_opts)
  --  feed_opts = feed_opts or "n"
  --  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(text, true, false, true), feed_opts, true)
  --end

  -- TODO Figure out what I'm doing wrong with these
  -- it("can copy the version out at the VERSION stage", function()
  --   coursier.complete_from_input()
  --   vim.wait(1000, function()
  --   end)
  --   local input = "org.scalameta:mdoc_2.13:1"
  --   feed(input)
  --   feed("<CR>")
  --   vim.wait(1000, function()
  --   end)
  --   feed("v")
  --   vim.wait(1000, function()
  --   end)
  --   local copied = vim.fn.getreg("+")
  --   assert.are.same(copied, "1.4.0-RC3")
  -- end)

  --it("can copy the dependency out correctly to sbt format at the VERSION stage", function()
  --  coursier.complete_from_input()
  --  feed("org.scalameta:mdoc_2.13:1", "")
  --  feed("<CR>", "")
  --  feed("s", "")
  --  local copied = vim.fn.getreg("+")
  --  assert.are.same(copied, [["org.scalameta" %% "mdoc" % "1.4.0-RC3"]])
  --end)
end)
