#include "server/ServerCore.h"
#include "CoreProcess.h"

int main(int argc, char* argv[]) {
	SortedVector<String> args;

	for (int i = 1; i < argc; ++i) {
		args.add(argv[i]);
	}

	CoreProcess process(args);
	process.run();

	return 0;
}
