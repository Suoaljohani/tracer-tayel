import UIKit

/// Renders a session into the Mock Tracer Form (vector reproduction of the provided form),
/// followed by a Trace Journey appendix: path, findings, decisions, evidence index and log.
@MainActor
struct ReportBuilder {
    let session: TraceSession

    // A4
    private let page = CGRect(x: 0, y: 0, width: 595.276, height: 841.89)
    private let scale: CGFloat = 495.0 / 757.0   // original form pixels → points
    private var left: CGFloat { 41.2 }
    private var right: CGFloat { 41.2 + 495 }

    // Form colours
    private let purple = UIColor(hex: 0x7030A0)
    private let cyan = UIColor(hex: 0x00B0F0)
    private let green = UIColor(hex: 0x92D050)
    private let labelFill = UIColor(hex: 0xF2F2F2)
    private let line = UIColor(hex: 0x1F1F1F)
    private let itlRed = UIColor(hex: 0xC00000)

    func write() -> URL {
        let data = render()
        let topic = (session.topic?.title ?? "Tracer").replacingOccurrences(of: "/", with: "-")
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let name = "Tracer Form – \(topic) – S\(session.number) – \(df.string(from: session.tracerDate)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }

    func render() -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Mock Tracer Form – \(session.topic?.title ?? "")",
            kCGPDFContextCreator as String: "Tracer Intelligence",
            kCGPDFContextAuthor as String: session.evaluator,
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)
        return renderer.pdfData { ctx in
            var pager = Pager(ctx: ctx, page: page)
            drawForm(&pager)
            drawJourney(&pager)
        }
    }

    // MARK: - Pager

    struct Pager {
        let ctx: UIGraphicsPDFRendererContext
        let page: CGRect
        var y: CGFloat = 0
        var pageNumber = 0
        let top: CGFloat = 54
        let bottom: CGFloat = 48

        init(ctx: UIGraphicsPDFRendererContext, page: CGRect) {
            self.ctx = ctx
            self.page = page
        }

        mutating func newPage() {
            ctx.beginPage()
            pageNumber += 1
            y = top
            let footer = "Tracer Intelligence  ·  \(pageNumber)"
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 7), .foregroundColor: UIColor(hex: 0x8A8F99)]
            (footer as NSString).draw(at: CGPoint(x: page.width - 41 - (footer as NSString).size(withAttributes: attrs).width, y: page.height - 30), withAttributes: attrs)
        }

        mutating func ensure(_ h: CGFloat) {
            if pageNumber == 0 || y + h > page.height - bottom { newPage() }
        }
    }

    // MARK: - Text helpers

    private static func hasArabic(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) || (0x0750...0x077F).contains($0.value) || (0xFB50...0xFEFF).contains($0.value) }
    }

    private func attr(_ s: String, size: CGFloat, bold: Bool = false, color: UIColor = .black, align: NSTextAlignment? = nil, italic: Bool = false) -> NSAttributedString {
        let arabic = Self.hasArabic(s)
        let p = NSMutableParagraphStyle()
        p.alignment = align ?? (arabic ? .right : .left)
        p.baseWritingDirection = arabic ? .rightToLeft : .leftToRight
        p.lineBreakMode = .byWordWrapping
        p.lineSpacing = 0.5
        var font: UIFont
        if arabic {
            font = Typography.uiFont(size, bold: bold)
        } else {
            font = bold ? UIFont(name: "Calibri-Bold", size: size) ?? .systemFont(ofSize: size, weight: .semibold)
                        : UIFont(name: "Calibri", size: size) ?? .systemFont(ofSize: size)
            if italic, let d = font.fontDescriptor.withSymbolicTraits(.traitItalic) { font = UIFont(descriptor: d, size: size) }
        }
        return NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: p])
    }

    private func height(_ a: NSAttributedString, width: CGFloat) -> CGFloat {
        ceil(a.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
    }

    private func draw(_ a: NSAttributedString, in r: CGRect, inset: CGFloat = 3, vCenter: Bool = false) {
        let inner = r.insetBy(dx: inset, dy: 2)
        var target = inner
        if vCenter {
            let h = height(a, width: inner.width)
            target = CGRect(x: inner.minX, y: inner.minY + max(0, (inner.height - h) / 2), width: inner.width, height: h)
        }
        a.draw(with: target, options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine], context: nil)
    }

    private func fill(_ r: CGRect, _ c: UIColor) {
        c.setFill(); UIRectFill(r)
    }

    private func stroke(_ r: CGRect, width: CGFloat = 0.5) {
        let p = UIBezierPath(rect: r)
        p.lineWidth = width
        line.setStroke()
        p.stroke()
    }

    private func hline(_ x1: CGFloat, _ x2: CGFloat, _ y: CGFloat, width: CGFloat = 0.5, color: UIColor? = nil) {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: x1, y: y)); p.addLine(to: CGPoint(x: x2, y: y))
        p.lineWidth = width
        (color ?? line).setStroke(); p.stroke()
    }

    private func vline(_ x: CGFloat, _ y1: CGFloat, _ y2: CGFloat, width: CGFloat = 0.5) {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: x, y: y1)); p.addLine(to: CGPoint(x: x, y: y2))
        p.lineWidth = width
        line.setStroke(); p.stroke()
    }

    /// Checkbox, optionally ticked (✓) or marked as suggested (○).
    private func checkbox(at p: CGPoint, size: CGFloat = 6.5, checked: Bool, suggested: Bool = false, color: UIColor = .black) {
        let r = CGRect(x: p.x, y: p.y, width: size, height: size)
        let b = UIBezierPath(rect: r)
        b.lineWidth = 0.6
        color.setStroke(); b.stroke()
        if checked {
            let t = UIBezierPath()
            t.move(to: CGPoint(x: r.minX + size * 0.18, y: r.midY))
            t.addLine(to: CGPoint(x: r.minX + size * 0.42, y: r.maxY - size * 0.18))
            t.addLine(to: CGPoint(x: r.maxX - size * 0.1, y: r.minY + size * 0.12))
            t.lineWidth = 1.3
            t.lineCapStyle = .round
            color.setStroke(); t.stroke()
        } else if suggested {
            let c = UIBezierPath(ovalIn: r.insetBy(dx: -2.5, dy: -2.5))
            c.lineWidth = 0.8
            c.setLineDash([1.5, 1.2], count: 2, phase: 0)
            color.setStroke(); c.stroke()
        }
    }

    private func x(_ px: CGFloat) -> CGFloat { left + (px - 63) * scale }

    // MARK: - Form

    private var formItems: [TraceItem] {
        let all = session.allItems
        let touched = all.filter { $0.hasAnswer || $0.compliance != .unset || $0.latestAnalysis != nil || !$0.planOfAction.isEmpty }
        return touched.isEmpty ? all : touched
    }

    private func drawForm(_ pager: inout Pager) {
        pager.newPage()
        pager.y = 74

        // Title bar
        let titleR = CGRect(x: left, y: pager.y, width: 495, height: 23)
        fill(titleR, purple)
        stroke(titleR)
        draw(attr("Mock Tracer Form", size: 13, bold: true, color: .white, align: .center), in: titleR, vCenter: true)
        pager.y = titleR.maxY

        drawHeader(&pager)
        pager.y += 14

        for item in formItems {
            drawBlock(item, &pager)
            pager.y += 13
        }
    }

    private func drawHeader(_ pager: inout Pager) {
        let lW = 98 * scale, dateVW = 101 * scale, timeLW = 90 * scale
        let midX = x(432), l2W = 85 * scale
        let topic = session.topic
        let deptLine = session.visitedDepartmentCodes.map { dept($0).englishName + (isArabic ? " / " + dept($0).nameAR : "") }.joined(separator: " → ")
        let dateF = DateFormatter(); dateF.dateStyle = .medium; dateF.locale = Locale(identifier: "en_GB")
        let timeF = DateFormatter(); timeF.dateFormat = "HH:mm"
        let team = [session.tracerTeam, session.evaluator].filter { !$0.isEmpty }.joined(separator: " · ")
        let docTitles = session.evidence.filter { $0.kind == .document || $0.kind == .record }.map(\.title)
        let docs = ([session.documentsReviewed] + docTitles).filter { !$0.isEmpty }.joined(separator: "; ")

        func row(minH: CGFloat, leftLabel: String, leftValue: NSAttributedString?, rightLabel: String, rightValue: String, custom: ((CGRect) -> Void)? = nil) {
            let rv = attr(rightValue, size: 8)
            let lv = leftValue
            let rightValueW = right - (midX + l2W)
            var h = minH
            h = max(h, height(rv, width: rightValueW - 6) + 6)
            if let lv { h = max(h, height(lv, width: midX - (left + lW) - 6) + 6) }
            let y = pager.y
            // label cells
            fill(CGRect(x: left, y: y, width: lW, height: h), labelFill)
            fill(CGRect(x: midX, y: y, width: l2W, height: h), labelFill)
            draw(attr(leftLabel, size: 7, color: UIColor(hex: 0x333333)), in: CGRect(x: left, y: y, width: lW, height: h), inset: 4)
            draw(attr(rightLabel, size: 7, color: UIColor(hex: 0x333333)), in: CGRect(x: midX, y: y, width: l2W, height: h), inset: 4)
            if let custom { custom(CGRect(x: left + lW, y: y, width: midX - left - lW, height: h)) }
            else if let lv { draw(lv, in: CGRect(x: left + lW, y: y, width: midX - left - lW, height: h), inset: 4) }
            draw(rv, in: CGRect(x: midX + l2W, y: y, width: rightValueW, height: h), inset: 4)
            stroke(CGRect(x: left, y: y, width: 495, height: h))
            vline(left + lW, y, y + h); vline(midX, y, y + h); vline(midX + l2W, y, y + h)
            pager.y += h
        }

        row(minH: 23, leftLabel: "Organization", leftValue: attr(session.organization, size: 8),
            rightLabel: "Department\nUnit", rightValue: deptLine)

        // Date / time row
        do {
            let y = pager.y
            let h: CGFloat = 23
            let tv = attr("\(topic?.title ?? "") (\(topic?.code ?? ""))", size: 8)
            let rh = max(h, height(tv, width: right - midX - l2W - 8) + 6)
            fill(CGRect(x: left, y: y, width: lW, height: rh), labelFill)
            fill(CGRect(x: left + lW + dateVW, y: y, width: timeLW, height: rh), labelFill)
            fill(CGRect(x: midX, y: y, width: l2W, height: rh), labelFill)
            draw(attr("Date of Tracer", size: 7, color: UIColor(hex: 0x333333)), in: CGRect(x: left, y: y, width: lW, height: rh), inset: 4)
            draw(attr(dateF.string(from: session.tracerDate), size: 8), in: CGRect(x: left + lW, y: y, width: dateVW, height: rh), inset: 4)
            draw(attr("Time of Tracer", size: 7, color: UIColor(hex: 0x333333)), in: CGRect(x: left + lW + dateVW, y: y, width: timeLW, height: rh), inset: 4)
            draw(attr(timeF.string(from: session.tracerDate), size: 8), in: CGRect(x: left + lW + dateVW + timeLW, y: y, width: midX - (left + lW + dateVW + timeLW), height: rh), inset: 4)
            draw(attr("Tracer Topic", size: 7, color: UIColor(hex: 0x333333)), in: CGRect(x: midX, y: y, width: l2W, height: rh), inset: 4)
            draw(tv, in: CGRect(x: midX + l2W, y: y, width: right - midX - l2W, height: rh), inset: 4)
            stroke(CGRect(x: left, y: y, width: 495, height: rh))
            for vx in [left + lW, left + lW + dateVW, left + lW + dateVW + timeLW, midX, midX + l2W] { vline(vx, y, y + rh) }
            pager.y += rh
        }

        // Type of tracer
        row(minH: 34, leftLabel: "Type of Tracer", leftValue: nil, rightLabel: "Tracer Team", rightValue: team) { r in
            let types: [[TracerType]] = [[.individual, .system, .program], [.highRisk, .environmentOfCare], [.lifeSafety]]
            var yy = r.minY + 4
            for rowTypes in types {
                var xx = r.minX + 5
                for t in rowTypes {
                    checkbox(at: CGPoint(x: xx, y: yy + 1.5), checked: topic?.tracerType == t)
                    let a = attr(t.formTitle, size: 7.2)
                    a.draw(at: CGPoint(x: xx + 9, y: yy))
                    xx += 9 + a.size().width + 8
                }
                yy += 10.5
            }
        }

        row(minH: 23, leftLabel: "Patient Record #\n(if applicable)", leftValue: attr(session.patientRecord, size: 8),
            rightLabel: "Documents\nReviewed", rightValue: docs)
    }

    private func drawBlock(_ item: TraceItem, _ pager: inout Pager) {
        let d = dept(item.node?.departmentCode)
        let splitX = x(346)
        let labelW = 79 * scale
        let compX = splitX, compW = 112 * scale
        let likX = compX + compW, likW = 72 * scale
        let lvlX = likX + likW, lvlW = 72 * scale
        let mX = lvlX + lvlW, mW = (right - mX) / 3
        let rowH: CGFloat = 10.6

        // Content
        let refs = StandardsLibrary.shared.standards(item.clauseIDs)
        let standardText = refs.isEmpty ? "" : refs.map { "\($0.id) — \($0.statement)" }.joined(separator: "\n")
        let stdAttr = attr(standardText, size: 7.5)
        let person = [item.personAsked, d.englishName + (isArabic ? " / \(d.nameAR)" : "")].filter { !$0.isEmpty }.joined(separator: " — ")
        let personAttr = attr(person, size: 8)

        let q = NSMutableAttributedString(attributedString: attr(item.questionText, size: 10.5))
        if item.hasAnswer {
            q.append(attr("\n", size: 4))
            q.append(attr(isArabic ? "إجابة الموظف:" : "Staff answer:", size: 7, bold: true, color: UIColor(hex: 0x555555)))
            q.append(attr("\n" + item.recordedAnswer, size: 8, color: UIColor(hex: 0x222222)))
        }
        let qW = splitX - left - 8
        let qH = height(q, width: qW) + 8

        let evidenceList = session.evidence.filter { $0.linkedItemIDs.contains(item.id) }.map { "[\($0.kind.rawValue)] \($0.title)\($0.verified ? " ✓" : "")" }
        let evText = ([item.evidenceOfCompliance] + evidenceList).filter { !$0.isEmpty }.joined(separator: "\n")
        let evAttr = attr(evText, size: 8)
        let planAttr = attr(item.planOfAction, size: 8)

        let hdrH: CGFloat = 16
        let personH = max(23, height(personAttr, width: splitX - left - labelW - 8) + 6, height(stdAttr, width: right - splitX - 8) + 6)
        let gridH = rowH * 6 + 2
        let mainH = max(gridH + rowH, qH)
        let evH = max(23, height(evAttr, width: right - left - labelW - 8) + 6)
        let planH = max(23, height(planAttr, width: x(602) - left - labelW - 8) + 6)
        let total = hdrH + personH + mainH + evH + planH

        pager.ensure(total)
        var y = pager.y

        // Header bar
        fill(CGRect(x: left, y: y, width: splitX - left, height: hdrH), cyan)
        fill(CGRect(x: splitX, y: y, width: right - splitX, height: hdrH), green)
        draw(attr("Tracer Question(s)", size: 9.5, bold: true), in: CGRect(x: left, y: y, width: splitX - left, height: hdrH), inset: 5, vCenter: true)
        draw(attr("Relevant Standard(s)", size: 9.5, bold: true), in: CGRect(x: splitX, y: y, width: right - splitX, height: hdrH), inset: 5, vCenter: true)
        hline(left, right, y + hdrH, width: 1.2)
        y += hdrH

        // Person asked / standards
        fill(CGRect(x: left, y: y, width: labelW, height: personH), labelFill)
        draw(attr("Person(s)\nAsked", size: 7, color: UIColor(hex: 0x333333)), in: CGRect(x: left, y: y, width: labelW, height: personH), inset: 4)
        draw(personAttr, in: CGRect(x: left + labelW, y: y, width: splitX - left - labelW, height: personH), inset: 4)
        draw(stdAttr, in: CGRect(x: splitX, y: y, width: right - splitX, height: personH), inset: 4)
        stroke(CGRect(x: left, y: y, width: 495, height: personH))
        vline(left + labelW, y, y + personH); vline(splitX, y, y + personH)
        y += personH

        // Main area: question + answer (left) and compliance grid (right)
        draw(q, in: CGRect(x: left, y: y, width: splitX - left, height: mainH), inset: 5)
        stroke(CGRect(x: left, y: y, width: 495, height: mainH))
        vline(splitX, y, y + mainH)

        let gy = y
        // Row 0 headers
        draw(attr("Compliant?", size: 7.5, italic: true), in: CGRect(x: compX, y: gy, width: compW, height: rowH), inset: 4, vCenter: true)
        draw(attr("If insufficient compliance:", size: 6.8, italic: true), in: CGRect(x: likX, y: gy - 0.5, width: mX - likX, height: rowH + 1), inset: 2, vCenter: true)
        fill(CGRect(x: mX, y: gy, width: right - mX, height: rowH), itlRed)
        let itl = item.riskApproved && item.approvedImmediateThreat
        let itlSuggested = !item.riskApproved && (item.latestAnalysis?.result?.immediate_threat ?? false)
        let itlLabel = attr("Immediate Threat to Life", size: 7.5, color: .white)
        let itlW = itlLabel.size().width + 10
        let itlX = mX + (right - mX - itlW) / 2
        checkbox(at: CGPoint(x: itlX, y: gy + 2), size: 6, checked: itl, suggested: itlSuggested, color: .white)
        itlLabel.draw(at: CGPoint(x: itlX + 10, y: gy + 0.5))

        // Compliance options rows 1-4
        let compliance: [(String, Compliance)] = [("Yes", .yes), ("No", .no), ("Not scored", .notScored), ("Not applicable", .notApplicable)]
        for (i, c) in compliance.enumerated() {
            let ry = gy + rowH * CGFloat(i + 1)
            checkbox(at: CGPoint(x: compX + 4, y: ry + 2), size: 6, checked: item.compliance == c.1,
                     suggested: item.compliance == .unset && item.latestAnalysis?.result?.complianceValue == c.1)
            attr(c.0, size: 7.5).draw(at: CGPoint(x: compX + 13, y: ry + 0.5))
            hline(compX, likX, ry)
        }
        // Likelihood labels
        draw(attr("Likelihood\nto Harm", size: 7.5, align: .center), in: CGRect(x: likX, y: gy + rowH, width: likW, height: rowH * 3), inset: 2)
        let levels: [(String, Likelihood)] = [("High", .high), ("Moderate", .moderate), ("Low", .low)]
        let scopes: [NoncomplianceScope] = [.limited, .pattern, .widespread]
        let approvedL = item.riskApproved ? item.approvedLikelihood : nil
        let approvedS = item.riskApproved ? item.approvedScope : nil
        let sugg = item.riskApproved ? nil : item.latestAnalysis?.result
        for (i, l) in levels.enumerated() {
            let ry = gy + rowH * CGFloat(i + 1)
            draw(attr(l.0, size: 7.5, align: .right), in: CGRect(x: lvlX, y: ry, width: lvlW, height: rowH), inset: 4, vCenter: true)
            for (j, s) in scopes.enumerated() {
                let cell = CGRect(x: mX + mW * CGFloat(j), y: ry, width: mW, height: rowH)
                fill(cell, SaferMatrixColors.color(l.1, s))
                let box = CGPoint(x: cell.midX - 3, y: cell.midY - 3)
                checkbox(at: box, size: 6, checked: approvedL == l.1 && approvedS == s,
                         suggested: sugg?.likelihoodValue == l.1 && sugg?.scopeValue == s)
            }
            hline(lvlX, right, ry)
        }
        // Scope labels row
        let sy = gy + rowH * 4
        for (j, s) in ["Limited", "Pattern", "Widespread"].enumerated() {
            draw(attr(s, size: 7.5, align: .center), in: CGRect(x: mX + mW * CGFloat(j), y: sy, width: mW, height: rowH), inset: 1, vCenter: true)
        }
        hline(lvlX, right, sy)
        hline(mX, right, sy + rowH)
        // Bottom gray row
        let by = gy + rowH * 5
        fill(CGRect(x: compX, y: by, width: right - compX, height: rowH + 1), labelFill)
        draw(attr("Scope of Noncompliance", size: 7.5, align: .center), in: CGRect(x: mX, y: by, width: right - mX, height: rowH), inset: 1, vCenter: true)
        hline(compX, right, by)
        hline(compX, right, by + rowH + 1)
        // grid verticals
        vline(likX, gy, by)
        vline(lvlX, gy + rowH, sy)
        vline(mX, gy, by + rowH + 1)
        vline(mX + mW, gy + rowH, sy + rowH)
        vline(mX + 2 * mW, gy + rowH, sy + rowH)
        hline(compX, right, gy + rowH)

        // Risk annotation under grid (when space allows)
        do {
            var note = ""
            if let a = item.approvedRisk { note = "Approved: \(a.englishTitle)" }
            if let s = item.suggestedRisk { note += (note.isEmpty ? "" : "   ") + "Suggested: \(s.englishTitle)" }
            if item.resolved { note += "   · Resolved" }
            if !note.isEmpty {
                draw(attr(note, size: 6.5, color: UIColor(hex: 0x555555)), in: CGRect(x: compX, y: by + rowH + 1, width: right - compX, height: rowH), inset: 4)
            }
        }
        y += mainH

        // Evidence of compliance
        fill(CGRect(x: left, y: y, width: labelW, height: evH), labelFill)
        draw(attr("Evidence of\nCompliance", size: 7, color: UIColor(hex: 0x333333)), in: CGRect(x: left, y: y, width: labelW, height: evH), inset: 4)
        draw(evAttr, in: CGRect(x: left + labelW, y: y, width: right - left - labelW, height: evH), inset: 4)
        stroke(CGRect(x: left, y: y, width: 495, height: evH))
        vline(left + labelW, y, y + evH)
        y += evH

        // Plan of action / due date
        let dueLX = x(602), dueVX = x(667)
        fill(CGRect(x: left, y: y, width: labelW, height: planH), labelFill)
        fill(CGRect(x: dueLX, y: y, width: dueVX - dueLX, height: planH), labelFill)
        draw(attr("Plan of\nAction", size: 7, color: UIColor(hex: 0x333333)), in: CGRect(x: left, y: y, width: labelW, height: planH), inset: 4)
        draw(planAttr, in: CGRect(x: left + labelW, y: y, width: dueLX - left - labelW, height: planH), inset: 4)
        draw(attr("Due Date", size: 7, color: UIColor(hex: 0x333333)), in: CGRect(x: dueLX, y: y, width: dueVX - dueLX, height: planH), inset: 4)
        if let due = item.dueDate {
            let f = DateFormatter(); f.dateStyle = .medium; f.locale = Locale(identifier: "en_GB")
            draw(attr(f.string(from: due), size: 8), in: CGRect(x: dueVX, y: y, width: right - dueVX, height: planH), inset: 4)
        }
        stroke(CGRect(x: left, y: y, width: 495, height: planH))
        vline(left + labelW, y, y + planH); vline(dueLX, y, y + planH); vline(dueVX, y, y + planH)
        hline(left, right, y + planH, width: 1.2)
        y += planH

        pager.y = y
    }

    // MARK: - Trace Journey appendix

    private func heading(_ text: String, _ pager: inout Pager, size: CGFloat = 13) {
        let a = attr(text, size: size, bold: true, color: UIColor(hex: 0x121620), align: isArabic ? .right : .left)
        let h = height(a, width: 495) + 4
        pager.ensure(h + 30)
        draw(a, in: CGRect(x: left, y: pager.y, width: 495, height: h), inset: 0)
        pager.y += h
        hline(left, right, pager.y, width: 0.6, color: UIColor(hex: 0xA88850))
        pager.y += 8
    }

    private func paragraph(_ text: String, _ pager: inout Pager, size: CGFloat = 8.5, color: UIColor = UIColor(hex: 0x333333), bold: Bool = false, indent: CGFloat = 0) {
        guard !text.isEmpty else { return }
        let a = attr(text, size: size, bold: bold, color: color, align: Self.hasArabic(text) || isArabic ? .natural : .left)
        let w = 495 - indent
        let h = height(a, width: w) + 2
        pager.ensure(h)
        draw(a, in: CGRect(x: left + (isArabic ? 0 : indent), y: pager.y, width: w, height: h + 2), inset: 0)
        pager.y += h + 2
    }

    private func drawJourney(_ pager: inout Pager) {
        pager.newPage()
        let topic = session.topic
        // Cover band
        let band = CGRect(x: 0, y: 0, width: page.width, height: 92)
        fill(band, UIColor(hex: 0x0B0F17))
        fill(CGRect(x: 0, y: band.maxY, width: page.width, height: 2), UIColor(hex: 0xC9A96E))
        draw(attr("TRACER  ·  TRACE JOURNEY", size: 8, bold: true, color: UIColor(hex: 0xC9A96E), align: isArabic ? .right : .left), in: CGRect(x: left, y: 22, width: 495, height: 14), inset: 0)
        draw(attr(topic?.title ?? "", size: 17, bold: true, color: .white, align: isArabic ? .right : .left), in: CGRect(x: left, y: 38, width: 495, height: 26), inset: 0)
        draw(attr("\(topic?.code ?? "") · v\(session.topicVersion) · \(L("Session", "الجلسة")) \(session.number) · \(session.status.title)", size: 8.5, color: UIColor(white: 1, alpha: 0.7), align: isArabic ? .right : .left),
             in: CGRect(x: left, y: 64, width: 495, height: 14), inset: 0)
        pager.y = band.maxY + 22

        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short; df.locale = AppSettings.shared.language.locale

        heading(L("Summary", "الملخص"), &pager)
        let top = session.topRisk
        let summaryLines = [
            L("Organization: ", "المنشأة: ") + session.organization,
            L("Evaluator: ", "المقيِّم: ") + session.evaluator + (session.tracerTeam.isEmpty ? "" : " · " + session.tracerTeam),
            L("Started: ", "البدء: ") + df.string(from: session.createdAt) + (session.closedAt.map { L(" · Closed: ", " · الإغلاق: ") + df.string(from: $0) } ?? ""),
            L("Departments: ", "الأقسام: ") + session.visitedDepartmentCodes.map { dept($0).name }.joined(separator: isArabic ? " ← " : " → "),
            L("Highest unresolved risk: ", "أعلى خطورة غير محسومة: ") + (top.map { "\($0.level.title) (\($0.approved ? L("approved", "معتمدة") : L("suggested — pending review", "مقترحة — بانتظار المراجعة")))" } ?? L("None", "لا يوجد")),
        ]
        for l in summaryLines { paragraph(l, &pager) }
        if !session.closeOverrideReason.isEmpty {
            paragraph(L("Closed by authorised override: ", "أُغلقت بتجاوز مصرح به: ") + session.closeOverrideReason, &pager, color: UIColor(hex: 0xC4510F), bold: true)
        }
        paragraph(L("Suggested = produced by the analysis service and not a decision. Approved = decision recorded by the evaluator. The two are reported separately.",
                    "المقترح = ناتج عن خدمة التحليل وليس قرارًا. المعتمد = قرار مسجل من المقيِّم. ويُعرض الاثنان بشكل منفصل."), &pager, size: 7.5, color: UIColor(hex: 0x777777))
        pager.y += 8

        heading(L("Trace path", "مسار التتبع"), &pager)
        drawPathDiagram(&pager)
        for e in session.edges.sorted(by: { $0.createdAt < $1.createdAt }) {
            let a = dept(session.nodes.first { $0.id == e.fromNodeID }?.departmentCode).name
            let b = dept(session.nodes.first { $0.id == e.toNodeID }?.departmentCode).name
            paragraph("• \(a) \(isArabic ? "←" : "→") \(b) — \(e.linkType.title) · \(df.string(from: e.createdAt))", &pager, bold: true)
            if !e.reason.isEmpty { paragraph(e.reason, &pager, indent: 10) }
            if !e.triggerQuestion.isEmpty { paragraph("“\(e.triggerQuestion)”", &pager, color: UIColor(hex: 0x777777), indent: 10) }
        }
        pager.y += 8

        heading(L("Findings & decisions", "الملاحظات والقرارات"), &pager)
        for node in session.orderedNodes {
            let d = dept(node.departmentCode)
            paragraph("\(d.name) — \(L("Trace point", "نقطة التتبع")) \(node.order + 1)\(node.closed ? L(" · closed", " · مغلقة") : "")", &pager, size: 10, color: UIColor(hex: d.primaryHex), bold: true)
            for item in node.orderedItems {
                paragraph("Q: " + item.questionText, &pager, bold: true, indent: 6)
                for r in item.orderedResponses {
                    paragraph("\(r.kind.title) (\(df.string(from: r.createdAt))): \(r.text)", &pager, indent: 12)
                }
                var line = L("Compliance: ", "الالتزام: ") + item.compliance.title
                line += "   " + L("Suggested risk: ", "الخطورة المقترحة: ") + (item.suggestedRisk?.title ?? "—")
                line += "   " + L("Approved risk: ", "الخطورة المعتمدة: ") + (item.approvedRisk?.title ?? L("not yet approved", "لم تُعتمد بعد"))
                if item.resolved { line += "   " + L("Resolved", "تمت المعالجة") }
                paragraph(line, &pager, color: UIColor(hex: (item.effectiveRisk ?? .undetermined).uiHex), indent: 12)
                if item.riskApproved {
                    paragraph(L("Decision: ", "القرار: ") + (item.riskDecidedAt.map { df.string(from: $0) } ?? "") + " · " + session.evaluator + (item.riskDecisionReason.isEmpty ? "" : " — " + item.riskDecisionReason), &pager, color: UIColor(hex: 0x555555), indent: 12)
                }
                if let r = item.latestAnalysis?.result {
                    paragraph(L("Analysis: ", "التحليل: ") + "\(r.completenessTitle) · \(r.correctnessTitle) · \(r.evidenceTitle) · \(r.confidenceTitle)", &pager, color: UIColor(hex: 0x555555), indent: 12)
                    if !r.missing_elements.isEmpty {
                        paragraph(L("Gaps: ", "النواقص: ") + r.missing_elements.joined(separator: isArabic ? "؛ " : "; "), &pager, indent: 12)
                    }
                    for c in r.conflicts {
                        paragraph(L("Conflict ", "تعارض ") + "[\(c.clause_id)]: \(c.description)", &pager, color: UIColor(hex: 0xC4510F), indent: 12)
                        paragraph("“\(c.clause_excerpt)”", &pager, size: 7.5, color: UIColor(hex: 0x777777), indent: 18)
                    }
                }
                if item.resolved && !item.resolutionNote.isEmpty {
                    paragraph(L("Resolution: ", "المعالجة: ") + item.resolutionNote, &pager, indent: 12)
                }
                pager.y += 4
            }
            pager.y += 4
        }

        heading(L("Evidence index", "فهرس الأدلة"), &pager)
        if session.evidence.isEmpty { paragraph(L("No evidence attached.", "لا توجد أدلة مرفقة."), &pager) }
        for ev in session.evidence.sorted(by: { $0.createdAt < $1.createdAt }) {
            paragraph("• \(ev.title) — \(ev.kind.title) · \(dept(ev.departmentCode).name) · \(df.string(from: ev.createdAt))\(ev.verified ? L(" · verified", " · تم التحقق") : "") · \(L("linked to", "مرتبط بـ")) \(ev.linkedItemIDs.count)", &pager)
            if !ev.note.isEmpty { paragraph(ev.note, &pager, color: UIColor(hex: 0x666666), indent: 10) }
            if ev.kind == .photo, let data = ev.data, let img = UIImage(data: data) {
                let w: CGFloat = 150
                let h = w * img.size.height / max(img.size.width, 1)
                pager.ensure(min(h, 200) + 6)
                img.draw(in: CGRect(x: isArabic ? right - w : left + 10, y: pager.y, width: w, height: min(h, 200)))
                pager.y += min(h, 200) + 6
            }
        }
        pager.y += 8

        heading(L("Change log", "سجل التغييرات"), &pager)
        for e in session.events.sorted(by: { $0.date < $1.date }) {
            paragraph("\(df.string(from: e.date)) · \(e.actor) — \(e.message)", &pager, size: 7.5)
        }
    }

    private func drawPathDiagram(_ pager: inout Pager) {
        let nodes = session.orderedNodes
        guard !nodes.isEmpty else { return }
        let perRow = 4
        let boxW: CGFloat = 96, boxH: CGFloat = 38, gapX: CGFloat = 32, gapY: CGFloat = 26
        let rows = Int(ceil(Double(nodes.count) / Double(perRow)))
        let totalH = CGFloat(rows) * boxH + CGFloat(rows - 1) * gapY + 10
        pager.ensure(totalH)
        var frames: [UUID: CGRect] = [:]
        for (i, n) in nodes.enumerated() {
            let r = i / perRow, c = i % perRow
            let col = isArabic ? (perRow - 1 - c) : c
            let fx = left + CGFloat(col) * (boxW + gapX)
            let fy = pager.y + CGFloat(r) * (boxH + gapY)
            frames[n.id] = CGRect(x: fx, y: fy, width: boxW, height: boxH)
        }
        // links
        for e in session.edges {
            guard let a = frames[e.fromNodeID], let b = frames[e.toNodeID] else { continue }
            let p = UIBezierPath()
            let start = CGPoint(x: a.midX, y: a.maxY)
            let end = CGPoint(x: b.midX, y: b.minY)
            if abs(a.minY - b.minY) < 1 {
                p.move(to: CGPoint(x: a.midX < b.midX ? a.maxX : a.minX, y: a.midY))
                p.addLine(to: CGPoint(x: a.midX < b.midX ? b.minX : b.maxX, y: b.midY))
            } else {
                p.move(to: start)
                p.addCurve(to: end, controlPoint1: CGPoint(x: start.x, y: start.y + 20), controlPoint2: CGPoint(x: end.x, y: end.y - 20))
            }
            p.lineWidth = 1.2
            if !e.linkType.dash.isEmpty { p.setLineDash(e.linkType.dash, count: e.linkType.dash.count, phase: 0) }
            UIColor(hex: 0xA88850).setStroke()
            p.stroke()
        }
        for n in nodes {
            guard let r = frames[n.id] else { continue }
            let d = dept(n.departmentCode)
            let path = UIBezierPath(roundedRect: r, cornerRadius: 8)
            UIColor(hex: d.backgroundHex).setFill(); path.fill()
            UIColor(hex: d.primaryHex).setStroke(); path.lineWidth = 1; path.stroke()
            UIColor(hex: d.primaryHex).setFill()
            UIBezierPath(roundedRect: CGRect(x: r.minX, y: r.minY, width: 4, height: r.height), cornerRadius: 2).fill()
            draw(attr(d.name, size: 8.5, bold: true, color: UIColor(hex: d.primaryHex), align: .center), in: CGRect(x: r.minX + 4, y: r.minY + 3, width: r.width - 6, height: 14), inset: 0)
            let risk = n.topRisk
            draw(attr("\(L("Point", "نقطة")) \(n.order + 1)" + (risk.map { " · \($0.title)" } ?? ""), size: 7, color: UIColor(hex: risk?.uiHex ?? 0x555555), align: .center),
                 in: CGRect(x: r.minX + 4, y: r.minY + 19, width: r.width - 6, height: 14), inset: 0)
        }
        pager.y += totalH + 6
    }
}

/// UIKit-side copy of the SAFER heat map colours (shared with the SwiftUI matrix).
enum SaferMatrixColors {
    static func color(_ l: Likelihood, _ s: NoncomplianceScope) -> UIColor {
        switch (l, s) {
        case (.high, _): return UIColor(hex: 0xFF0000)
        case (.moderate, .limited): return UIColor(hex: 0xFFC000)
        case (.moderate, _): return UIColor(hex: 0xED7D31)
        case (.low, .limited): return UIColor(hex: 0xFFFF00)
        default: return UIColor(hex: 0xFFC000)
        }
    }
}
