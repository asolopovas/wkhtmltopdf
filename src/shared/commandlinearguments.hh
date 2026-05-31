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

#ifndef __COMMANDLINEARGUMENTS_HH__
#define __COMMANDLINEARGUMENTS_HH__

#include <QtCore/QByteArray>
#include <QtCore/QString>
#include <QtCore/QVector>
#include <QtCore/qglobal.h>

#ifdef Q_OS_WIN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <shellapi.h>
#endif

inline QString commandLineArgToQString(const char * arg) {
#ifdef Q_OS_WIN
	return QString::fromUtf8(arg);
#else
	return QString::fromLocal8Bit(arg);
#endif
}

class CommandLineArguments {
public:
	CommandLineArguments(int argc, char ** argv) {
#ifdef Q_OS_WIN
		int wideArgc = 0;
		LPWSTR * wideArgv = CommandLineToArgvW(GetCommandLineW(), &wideArgc);
		if (wideArgv != 0) {
			for (int i = 0; i < wideArgc; ++i)
				storage.append(QString::fromWCharArray(wideArgv[i]).toUtf8());
			LocalFree(wideArgv);
		} else
#endif
		{
			for (int i = 0; i < argc; ++i)
				storage.append(QByteArray(argv[i]));
		}

		for (int i = 0; i < storage.size(); ++i) {
			argvData.append(storage[i].data());
			constArgvData.append(storage[i].constData());
		}
		argvData.append(0);
		constArgvData.append(0);
	}

	int argc() const {
		return storage.size();
	}

	char ** argv() {
		return argvData.data();
	}

	const char ** constArgv() {
		return constArgvData.data();
	}

private:
	QVector<QByteArray> storage;
	QVector<char *> argvData;
	QVector<const char *> constArgvData;
};

#endif //__COMMANDLINEARGUMENTS_HH__
