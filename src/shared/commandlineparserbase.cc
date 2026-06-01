// -*- mode: c++; tab-width: 4; indent-tabs-mode: t; eval: (progn (c-set-style "stroustrup") (c-set-offset 'innamespace 0)); -*-
// vi:set ts=4 sts=4 sw=4 noet :
//
// Copyright 2010-2020 wkhtmltopdf authors
//
// This file is part of wkhtmltopdf.
//
// wkhtmltopdf is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// wkhtmltopdf is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with wkhtmltopdf.  If not, see <http://www.gnu.org/licenses/>.

#include "commandlineparserbase.hh"
#include "outputter.hh"
#include <algorithm>
#include <cstdlib>
#include <qdir.h>
#include <qfile.h>
#include <qset.h>
#include <qstringlist.h>
#include <qwebframe.h>

struct SortPrefix {
	const char * text;
	int length;
};

static QString strippedSortName(const QString & name) {
	static const SortPrefix prefixes[] = {
		{"no-", 3},
		{"enable-", 7},
		{"disable-", 8},
		{"include-in-", 11},
		{"exclude-from-", 13}
	};
	for (unsigned int i=0; i < sizeof(prefixes) / sizeof(prefixes[0]); ++i) {
		if (name.startsWith(QLatin1String(prefixes[i].text)))
			return name.mid(prefixes[i].length);
	}
	return name;
}

static QString noLastSortName(const QString & name) {
	if (name.startsWith(QLatin1String("no-")))
		return QLatin1String("zzzz") + name.mid(3);
	return name;
}

bool ahsort(const ArgHandler * a, const ArgHandler * b) {
	QString x = strippedSortName(a->longName);
	QString y = strippedSortName(b->longName);
	if (x == y) {
		x = noLastSortName(a->longName);
		y = noLastSortName(b->longName);
	}
	return x < y;
}

/*!
  Output description of switches to an outputter
  \param o The outputter to output to
  \param extended Should we also output extended arguments
  \param doc Indicate to the outputter that it is writing documentation
*/
void CommandLineParserBase::outputSwitches(Outputter * o, bool extended, bool doc) const {
	for (int sectionIndex = 0; sectionIndex < sections.size(); ++sectionIndex) {
		const QString section = sections.at(sectionIndex);
		QList<const ArgHandler *> display;
		const QList<ArgHandler *> handlers = sectionArgumentHandles[section];
		for (int handlerIndex = 0; handlerIndex < handlers.size(); ++handlerIndex) {
			const ArgHandler * handler = handlers.at(handlerIndex);
#ifndef __EXTENSIVE_WKHTMLTOPDF_QT_HACK__
			if (!doc && handler->qthack) continue;
#else
			Q_UNUSED(doc);
#endif
			if (!extended && handler->extended) continue;
			display.push_back(handler);
		}
		std::sort(display.begin(), display.end(), ahsort);
		if (display.size() == 0) continue;
		o->beginSection(section);
		if (!sectionDesc[section].isEmpty()) {
			o->beginParagraph();
			o->text(sectionDesc[section]);
			o->endParagraph();
		}
		o->beginSwitch();
		for (int handlerIndex = 0; handlerIndex < display.size(); ++handlerIndex)
			o->cswitch(display.at(handlerIndex));
		o->endSwitch();
		o->endSection();
 	}
}

static QString shellQuote(const QString & value) {
	QString quoted = value;
	quoted.replace("'", "'\\''");
	return "'" + quoted + "'";
}

static QString completionDescription(const ArgHandler * handler) {
	QString desc = handler->getDesc();
	desc.replace('\n', ' ');
	desc.replace('\r', ' ');
	desc.replace('[', '(');
	desc.replace(']', ')');
	return desc;
}

static QString completionChoices(const QString & longName) {
	if (longName == "completion")
		return "bash zsh fish";
	if (longName == "log-level")
		return "none error warn info debug";
	if (longName == "load-error-handling" || longName == "load-media-error-handling")
		return "abort ignore skip";
	if (longName == "orientation")
		return "Portrait Landscape";
	if (longName == "format")
		return "jpg jpeg png bmp svg";
	return QString();
}

static QString completionArgName(const ArgHandler * handler) {
	if (!handler->argn.size())
		return QString();
	return handler->argn[0];
}

static QString zshCompletionSuffix(const ArgHandler * handler) {
	QString choices = completionChoices(handler->longName);
	if (!choices.isEmpty())
		return ":" + completionArgName(handler) + ":(" + choices + ")";
	QString argName = completionArgName(handler);
	return argName.isEmpty() ? QString() : ":" + argName + ":_files";
}

static QString envValue(const char * name) {
	const char * value = getenv(name);
	return value ? QString::fromLocal8Bit(value) : QString();
}

static QString currentShellName() {
	QString shell = envValue("SHELL");
	int slash = shell.lastIndexOf('/');
	if (slash >= 0)
		shell = shell.mid(slash + 1);
	if (shell.endsWith(".exe", Qt::CaseInsensitive))
		shell.chop(4);
	return shell;
}

bool CommandLineParserBase::outputCompletion(FILE * fd, const QString & shell) const {
	const QString app = appName();
	QList<const ArgHandler *> handlers;
	QSet<QString> seen;
	for (int sectionIndex = 0; sectionIndex < sections.size(); ++sectionIndex) {
		const QString section = sections.at(sectionIndex);
		const QList<ArgHandler *> sectionHandlers = sectionArgumentHandles[section];
		for (int handlerIndex = 0; handlerIndex < sectionHandlers.size(); ++handlerIndex) {
			const ArgHandler * handler = sectionHandlers.at(handlerIndex);
			if (!handler->display || seen.contains(handler->longName)) continue;
			seen.insert(handler->longName);
			handlers.push_back(handler);
		}
	}
	std::sort(handlers.begin(), handlers.end(), ahsort);

	if (shell == "bash") {
		QStringList words;
		for (int handlerIndex = 0; handlerIndex < handlers.size(); ++handlerIndex) {
			const ArgHandler * handler = handlers.at(handlerIndex);
			words << "--" + handler->longName;
			if (handler->shortSwitch != 0)
				words << "-" + QString(QChar(handler->shortSwitch));
		}
		if (app == "wkhtmltopdf")
			words << "page" << "cover" << "toc";

		fprintf(fd,
			"# bash completion for %s\n"
			"_%s_completion()\n"
			"{\n"
			"    local cur prev opts\n"
			"    COMPREPLY=()\n"
			"    cur=${COMP_WORDS[COMP_CWORD]}\n"
			"    prev=${COMP_WORDS[COMP_CWORD-1]}\n"
			"    opts=%s\n"
			"\n"
			"    case \"$prev\" in\n"
			"        --completion) COMPREPLY=( $(compgen -W \"bash zsh fish\" -- \"$cur\") ); return 0 ;;\n"
			"        --log-level) COMPREPLY=( $(compgen -W \"none error warn info debug\" -- \"$cur\") ); return 0 ;;\n"
			"        --load-error-handling|--load-media-error-handling) COMPREPLY=( $(compgen -W \"abort ignore skip\" -- \"$cur\") ); return 0 ;;\n"
			"        --orientation|-O) COMPREPLY=( $(compgen -W \"Portrait Landscape\" -- \"$cur\") ); return 0 ;;\n"
			"        --format|-f) COMPREPLY=( $(compgen -W \"jpg jpeg png bmp svg\" -- \"$cur\") ); return 0 ;;\n"
			"    esac\n"
			"\n"
			"    if [[ $cur == -* ]]; then\n"
			"        COMPREPLY=( $(compgen -W \"$opts\" -- \"$cur\") )\n"
			"        return 0\n"
			"    fi\n"
			"\n"
			"    COMPREPLY=( $(compgen -f -- \"$cur\") )\n"
			"    return 0\n"
			"}\n"
			"complete -F _%s_completion %s\n",
			app.toLocal8Bit().constData(), app.toLocal8Bit().constData(),
			shellQuote(words.join(" ")).toLocal8Bit().constData(),
			app.toLocal8Bit().constData(), app.toLocal8Bit().constData());
		return true;
	}

	if (shell == "zsh") {
		fprintf(fd,
			"#compdef %s\n"
			"# zsh completion for %s\n"
			"_%s() {\n"
			"  _arguments -s \\\n",
			app.toLocal8Bit().constData(), app.toLocal8Bit().constData(), app.toLocal8Bit().constData());
		for (int handlerIndex = 0; handlerIndex < handlers.size(); ++handlerIndex) {
			const ArgHandler * handler = handlers.at(handlerIndex);
			QString desc = completionDescription(handler);
			QString suffix = zshCompletionSuffix(handler);
			QString longSpec = "--" + handler->longName + "[" + desc + "]" + suffix;
			fprintf(fd, "    %s \\\n", shellQuote(longSpec).toLocal8Bit().constData());
			if (handler->shortSwitch != 0) {
				QString shortSpec = "-" + QString(QChar(handler->shortSwitch)) + "[" + desc + "]" + suffix;
				fprintf(fd, "    %s \\\n", shellQuote(shortSpec).toLocal8Bit().constData());
			}
		}
		if (app == "wkhtmltopdf")
			fprintf(fd, "    '(page cover toc)'{page,cover,toc}'[document object]' \\\n");
		fprintf(fd, "    '*:file:_files'\n}\n_%s \"$@\"\n", app.toLocal8Bit().constData());
		return true;
	}

	if (shell == "fish") {
		fprintf(fd, "# fish completion for %s\n", app.toLocal8Bit().constData());
		if (app == "wkhtmltopdf") {
			fprintf(fd, "complete -c %s -f -a page -d 'PDF page object'\n", app.toLocal8Bit().constData());
			fprintf(fd, "complete -c %s -f -a cover -d 'PDF cover object'\n", app.toLocal8Bit().constData());
			fprintf(fd, "complete -c %s -f -a toc -d 'PDF table of contents object'\n", app.toLocal8Bit().constData());
		}
		for (int handlerIndex = 0; handlerIndex < handlers.size(); ++handlerIndex) {
			const ArgHandler * handler = handlers.at(handlerIndex);
			QString line = "complete -c " + app + " -l " + handler->longName;
			if (handler->shortSwitch != 0)
				line += " -s " + QString(QChar(handler->shortSwitch));
			if (handler->argn.size())
				line += " -r";
			line += " -d " + shellQuote(completionDescription(handler));
			QString choices = completionChoices(handler->longName);
			if (!choices.isEmpty())
				line += " -a " + shellQuote(choices);
			fprintf(fd, "%s\n", line.toLocal8Bit().constData());
		}
		return true;
	}

	return false;
}

bool CommandLineParserBase::installCompletion(FILE * out, FILE * err) const {
	QString shell = currentShellName();
	if (shell != "bash" && shell != "zsh" && shell != "fish") {
		fprintf(err, "Unsupported or unknown active shell '%s'. Use --completion <bash|zsh|fish> to generate a script manually.\n",
			shell.isEmpty() ? "" : shell.toLocal8Bit().constData());
		return false;
	}

	QString home = envValue("HOME");
	if (home.isEmpty()) {
		fprintf(err, "HOME is not set; cannot choose a user completion directory.\n");
		return false;
	}

	QString path;
	if (shell == "bash") {
		QString dataHome = envValue("XDG_DATA_HOME");
		if (dataHome.isEmpty()) dataHome = home + "/.local/share";
		path = dataHome + "/bash-completion/completions/" + appName();
	} else if (shell == "fish") {
		QString configHome = envValue("XDG_CONFIG_HOME");
		if (configHome.isEmpty()) configHome = home + "/.config";
		path = configHome + "/fish/completions/" + appName() + ".fish";
	} else {
		QString zdotdir = envValue("ZDOTDIR");
		if (zdotdir.isEmpty()) zdotdir = home;
		path = zdotdir + "/.zfunc/_" + appName();
	}

	int slash = path.lastIndexOf('/');
	QString dir = slash >= 0 ? path.left(slash) : QString(".");
	if (!QDir().mkpath(dir)) {
		fprintf(err, "Could not create completion directory: %s\n", dir.toLocal8Bit().constData());
		return false;
	}

	FILE * fd = fopen(QFile::encodeName(path).constData(), "wb");
	if (!fd) {
		fprintf(err, "Could not write completion file: %s\n", path.toLocal8Bit().constData());
		return false;
	}

	bool ok = outputCompletion(fd, shell);
	if (fclose(fd) != 0)
		ok = false;
	if (!ok) {
		fprintf(err, "Could not install %s completion.\n", shell.toLocal8Bit().constData());
		return false;
	}

	fprintf(out, "Installed %s completion for %s to %s\n",
		shell.toLocal8Bit().constData(), appName().toLocal8Bit().constData(), path.toLocal8Bit().constData());
	if (shell == "zsh")
		fprintf(out, "Ensure this directory is in fpath, for example: fpath=(%s $fpath)\n", dir.toLocal8Bit().constData());
	return true;
}

#define STRINGIZE_(x) #x
#define STRINGIZE(x) STRINGIZE_(x)

const char *CommandLineParserBase::appVersion() const {
#ifdef __EXTENSIVE_WKHTMLTOPDF_QT_HACK__
	return STRINGIZE(FULL_VERSION) " (with patched Qt)";
#else
	return STRINGIZE(FULL_VERSION);
#endif
}

/*!
  Output version information aka. --version
  \param fd The file to output to
*/
void CommandLineParserBase::version(FILE * fd) const {
	fprintf(fd, "%s %s\n", appName().toLocal8Bit().constData(), appVersion());
}

/*!
  Output license information aka. --license
  \param fd The file to output to
*/
void CommandLineParserBase::license(FILE * fd) const {
 	Outputter * o = Outputter::text(fd,false);
  	outputName(o);
  	outputAuthors(o);
  	outputLicense(o);
	delete o;
}

void CommandLineParserBase::parseArg(int sections, const int argc, const char ** argv, bool & defaultMode, int & arg, char * page) {
	if (argv[arg][1] == '-') { //We have a long style argument
		//After an -- apperas in the argument list all that follows is interpreted as default arguments
		if (argv[arg][2] == '0') {
			defaultMode=true;
			return;
		}
		//Try to find a handler for this long switch
		QHash<QString, ArgHandler*>::iterator j = longToHandler.find(argv[arg]+2);
		if (j == longToHandler.end()) { //Ups that argument did not exist
			fprintf(stderr, "Unknown long argument %s\n\n", argv[arg]);
			usage(stderr, false);
			exit(1);
		}
		if (!(j.value()->section & sections)) {
			fprintf(stderr, "%s specified in incorrect location\n\n", argv[arg]);
			usage(stderr, false);
			exit(1);
		}
		//Check to see if there is enough arguments to the switch
		if (argc-arg < j.value()->argn.size()+1) {
			fprintf(stderr, "Not enough arguments parsed to %s\n\n", argv[arg]);
			usage(stderr, false);
			exit(1);
		}
		if (!(*(j.value()))(argv+arg+1, *this, page)) {
			fprintf(stderr, "Invalid argument(s) parsed to %s\n\n", argv[arg]);
			usage(stderr, false);
			exit(1);
		}
#ifndef __EXTENSIVE_WKHTMLTOPDF_QT_HACK__
		if (j.value()->qthack)
			fprintf(stderr, "The switch %s is not supported when using unpatched Qt and will be ignored.", argv[arg]);
#endif
		//Skip already handled switch arguments
		arg += j.value()->argn.size();
	} else {
		int c=arg;//Remember the current argument we are parsing
		for (int j=1; argv[c][j] != '\0'; ++j) {
			QHash<char, ArgHandler*>::iterator k = shortToHandler.find(argv[c][j]);
			//If the short argument is invalid print usage information and exit
			if (k == shortToHandler.end()) {
				fprintf(stderr, "Unknown switch -%c\n\n", argv[c][j]);
				usage(stderr, false);
				exit(1);
			}

			if (!(k.value()->section & sections)) {
				fprintf(stderr, "-%c specified in incorrect location\n\n", argv[c][j]);
				usage(stderr, false);
				exit(1);
			}
			//Check to see if there is enough arguments to the switch
			if (argc-arg < k.value()->argn.size()+1) {
				fprintf(stderr, "Not enough arguments parsed to -%c\n\n", argv[c][j]);
				usage(stderr, false);
				exit(1);
			}
			if (!(*(k.value()))(argv+arg+1, *this, page)) {
				fprintf(stderr, "Invalid argument(s) parsed to -%c\n\n", argv[c][j]);
				usage(stderr, false);
				exit(1);
			}
#ifndef __EXTENSIVE_WKHTMLTOPDF_QT_HACK__
 			if (k.value()->qthack)
				fprintf(stderr, "The switch -%c is not supported when using unpatched Qt and will be ignored.", argv[c][j]);
#endif
			//Skip already handled switch arguments
			arg += k.value()->argn.size();
		}
	}
}
