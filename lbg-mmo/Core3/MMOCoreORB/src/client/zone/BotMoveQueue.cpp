/*
 * BotMoveQueue.cpp
 *
 * Lignes : move_to|Lia|x|y|z[|stopM]
 *          stop|Lia
 */
#include "BotMoveQueue.h"

#include "system/io/StringTokenizer.h"

#include <fstream>
#include <vector>

BotMoveQueue::BotMoveQueue(const String& path, const String& characterName) {
	queuePath = path;
	characterFilter = characterName.toLowerCase();
}

static String trimLine(String line) {
	line = line.trim();
	if (line.length() > 0 && line.charAt(line.length() - 1) == '\r') {
		line = line.subString(0, line.length() - 1);
	}
	return line;
}

static bool nameMatches(const String& field, const String& filterLower) {
	if (filterLower.isEmpty()) {
		return true;
	}
	return field.toLowerCase() == filterLower;
}

static bool parseLine(const String& line, const String& filterLower, BotMoveCommand& parsed) {
	if (line.isEmpty()) {
		return false;
	}

	StringTokenizer tok(line);
	tok.setDelimeter("|");

	if (!tok.hasMoreTokens()) {
		return false;
	}

	String verb = tok.getStringToken().toLowerCase();
	if (!tok.hasMoreTokens()) {
		return false;
	}

	String who = tok.getStringToken();
	if (!nameMatches(who, filterLower)) {
		return false;
	}

	parsed.valid = true;
	parsed.verb = verb;

	if (verb == "stop") {
		return true;
	}

	if (verb == "sync_pos") {
		if (!tok.hasMoreTokens()) {
			parsed.valid = false;
			return false;
		}
		parsed.x = tok.getFloatToken();
		if (!tok.hasMoreTokens()) {
			parsed.valid = false;
			return false;
		}
		parsed.y = tok.getFloatToken();
		parsed.z = 0.f;
		if (tok.hasMoreTokens()) {
			parsed.z = tok.getFloatToken();
		}
		return true;
	}

	if (verb != "move_to") {
		parsed.valid = false;
		return false;
	}

	if (!tok.hasMoreTokens()) {
		parsed.valid = false;
		return false;
	}

	parsed.x = tok.getFloatToken();
	if (!tok.hasMoreTokens()) {
		parsed.valid = false;
		return false;
	}
	parsed.y = tok.getFloatToken();
	parsed.z = 0.f;
	parsed.stopRadiusM = 2.f;

	if (tok.hasMoreTokens()) {
		parsed.z = tok.getFloatToken();
	}
	if (tok.hasMoreTokens()) {
		parsed.stopRadiusM = tok.getFloatToken();
	}

	return true;
}

BotMoveCommand BotMoveQueue::poll() {
	BotMoveCommand out;
	out.valid = false;

	std::ifstream in(queuePath.toCharArray());
	if (!in.is_open()) {
		return out;
	}

	std::vector<std::string> lines;
	std::string raw;

	while (std::getline(in, raw)) {
		if (!raw.empty()) {
			lines.push_back(raw);
		}
	}
	in.close();

	if (lines.empty()) {
		return out;
	}

	int chosen = -1;
	BotMoveCommand parsed;

	for (size_t i = 0; i < lines.size(); ++i) {
		BotMoveCommand candidate;
		if (!parseLine(trimLine(String(lines[i].c_str())), characterFilter, candidate)) {
			continue;
		}
		parsed = candidate;
		chosen = (int)i;
		break;
	}

	if (chosen < 0 || !parsed.valid) {
		return out;
	}

	std::ofstream outFile(queuePath.toCharArray(), std::ios::trunc);
	if (outFile.is_open()) {
		for (size_t i = 0; i < lines.size(); ++i) {
			if ((int)i == chosen) {
				continue;
			}
			outFile << lines[i] << '\n';
		}
	}

	return parsed;
}
