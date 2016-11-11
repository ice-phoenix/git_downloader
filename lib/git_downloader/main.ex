defmodule GitDownloader do
	use Application

	def start(_type, _args) do
		GitDownloader.Supervisor.start_link
	end
end

defmodule GitDownloader.Main do

	import GitDownloader.Util

	@github_url "https://api.github.com"

	def get_all_forks_for(owner, repo) do
		{:ok, get_all_forks_for_aux(~s(#{@github_url}/repos/#{owner}/#{repo}/forks), [])}
	end

	defp get_all_forks_for_aux(url, acc) do
		{:ok, %HTTPoison.Response{status_code: 200, headers: headers, body: body}} = HTTPoison.get(url)

		links = case Proplist.get(headers, "Link") do
			nil -> []
			e -> e |>
				String.split(", ") |>
				Stream.map(&String.split(&1, "; ")) |>
				Stream.map(fn([url_, id_]) ->
					<<"rel=", id::binary>> = id_
					url_size = byte_size(url_) - 2
					<<_::binary-size(1),url::binary-size(url_size),_::binary-size(1)>> = url_
					{id, url}
				end) |>
				Enum.to_list
		end

		{:ok, json} = Poison.Parser.parse(body)
		forks = json |> Stream.map(&(&1["clone_url"])) |> Enum.to_list

		case Proplist.get(links, "\"next\"") do
			nil -> acc ++ forks
			next -> get_all_forks_for_aux(next, acc ++ forks)
		end
	end

	def clone_git_repo(repo, target_root) do
		Task.Supervisor.start_child({:global, GitDownloader.TaskSupervisor}, fn ->
			[_, _, repo_name, _] = String.split(repo, "/", trim: true)
			target_dir = ~s(#{target_root}/#{repo_name})
			try do
				Sh.bash(c: ~t(git clone #{repo} #{target_dir}))
			rescue
				_ in Sh.AbnormalExit -> Sh.bash(c: ~t(cd #{target_dir} && git pull))
			end
		end)
	end

	def clone_all_forks_for(owner, repo, target_root) do
		{:ok, forks} = get_all_forks_for(owner, repo)
		Enum.each(forks, &clone_git_repo(&1, target_root))
	end

end
