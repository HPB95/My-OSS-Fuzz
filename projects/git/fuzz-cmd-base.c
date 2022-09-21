#include "cache.h"
#include "fuzz-cmd-base.h"


/*
 * This function is used to randomize the content of a file with the
 * random data. The random data normally come from the fuzzing engine
 * LibFuzzer in order to create randomization of the git file worktree
 * and possibly messing up of certain git config file to fuzz different
 * git command execution logic. Return -1 if it fails to create the file.
 */
int randomize_git_file(char *dir, char *name, char *data, int size)
{
	FILE *fp;
	int ret = 0;
	struct strbuf fname = STRBUF_INIT;

	strbuf_addf(&fname, "%s/%s", dir, name);

	fp = fopen(fname.buf, "wb");
	if (fp)
	{
		fwrite(data, 1, size, fp);
	}
	else
	{
		ret = -1;
	}

	fclose(fp);
	strbuf_release(&fname);

	return ret;
}

/*
 * This function is a variant of the above function which takes
 * a set of target files to be processed. These target file are
 * passing to the above function one by one for content rewrite.
 * The data is equally divided for each of the files, and the
 * remaining bytes (if not divisible) will be ignored.
 */
void randomize_git_files(char *dir, char *name_set[],
	int files_count, char *data, int size)
{
	int i;
	int data_size = size / files_count;
	char *data_chunk = xmallocz_gently(data_size);

	if (!data_chunk)
	{
		return;
	}

	for (i = 0; i < files_count; i++)
	{
		memcpy(data_chunk, data + (i * data_size), data_size);
		randomize_git_file(dir, name_set[i], data_chunk, data_size);
	}
	free(data_chunk);
}

/*
 * Instead of randomizing the content of existing files. This helper
 * function helps generate a temp file with random file name before
 * passing to the above functions to get randomized content for later
 * fuzzing of git command.
 */
void generate_random_file(char *data, int size)
{
	unsigned char *hash = xmallocz_gently(size);
	char *data_chunk = xmallocz_gently(size);
	struct strbuf fname = STRBUF_INIT;

	if (!hash || !data_chunk)
	{
		return;
	}

	memcpy(hash, data, size);
	memcpy(data_chunk, data + size, size);

	strbuf_addf(&fname, "TEMP-%s-TEMP", hash_to_hex(hash));
	randomize_git_file(".", fname.buf, data_chunk, size);

	free(hash);
	free(data_chunk);
	strbuf_release(&fname);
}

/*
 * This function provides a shorthand for generate commit in master
 * branch.
 */
void generate_commit(char *data, int size)
{
	generate_commit_in_branch(data, size, "master");
}

/*
 * This function helps to generate random commit and build up a
 * worktree with randomization to provide a target for the fuzzing
 * of git command under specific branch.
 */
void generate_commit_in_branch(char *data, int size, char *branch_name)
{
	char *data_chunk = xmallocz_gently(HASH_HEX_SIZE);
	struct strbuf push_cmd = STRBUF_INIT;

	if (!data_chunk)
	{
		return;
	}

	memcpy(data_chunk, data, size * 2);
	generate_random_file(data_chunk, size);

	free(data_chunk);

	strbuf_addf(&push_cmd, "git push origin %s", branch_name);

	if (system("git add TEMP-*-TEMP") ||
		system("git commit -m\"New Commit\""))
//		system("git commit -m\"New Commit\"") ||
//		system(push_cmd.buf))
	{
		// Just skip the commit if fails
		strbuf_release(&push_cmd);
		return;
	}
	strbuf_release(&push_cmd);
}

/*
 * In some cases, there maybe some fuzzing logic that will mess
 * up with the git repository and its configuration and settings.
 * This function integrates into the fuzzing processing and
 * reset the git repository into the default
 * base settings before each round of fuzzing.
 * Return values from system are ignored.
 */
void reset_git_folder(void)
{
	if (system("rm -rf ./.git") ||
		system("rm -f ./TEMP-*-TEMP") ||
		system("git init") ||
		system("git config --global user.name \"FUZZ\"") ||
		system("git config --global user.email \"FUZZ@LOCALHOST\"") ||
		system("git config --global --add safe.directory '*'") ||
		system("rm -rf /tmp/oss-test.git") ||
		system("cp -r /tmp/backup.git /tmp/oss-test.git") ||
		system("git remote add origin /tmp/oss-test.git") ||
		system("git fetch origin") ||
		system("git reset --hard origin/master"))
	{
		// Error in these does not affect git command.
		return;
	}
}

/*
 * This helper function returns the maximum number of commit can
 * be generated by the provided random data without reusing the
 * data to increase randomization of the fuzzing target and allow
 * more path of fuzzing to be covered.
 */
int get_max_commit_count(int data_size, int git_files_count, int hash_size)
{
	int count = (data_size - 4 - git_files_count * 2) / (hash_size * 2);

	if (count > 20)
	{
		count = 20;
	}

	return count;
}
