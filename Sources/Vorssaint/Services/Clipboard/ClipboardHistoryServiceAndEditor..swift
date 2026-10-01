//
//  ClipboardHistoryServiceAndEditor..swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 9/30/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The service already has exactly these members, so the conformance is empty.
/// It lives in its own file because the model's file is also compiled by the
/// test build, which does not include the service.
extension ClipboardHistoryService: ClipboardEditorHistory {}
