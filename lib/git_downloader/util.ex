defmodule GitDownloader.Util do
	def sigil_t(str, []) do
		IO.puts(~s(T:#{str}))
		str
	end
end
